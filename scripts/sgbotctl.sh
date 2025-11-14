#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="sgmessengerbot"
INSTALL_DIR="${INSTALL_DIR:-/opt/SGMessengerBot}"
RUN_USER="${RUN_USER:-sgmessenger}"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"

usage() {
  echo "用法: $0 <命令> [选项]"
  echo "命令:"
  echo "  install           安装并配置服务"
  echo "  enable            设置开机自启动"
  echo "  disable           禁用服务开机启动"
  echo "  start             启动后端"
  echo "  stop              关闭后端"
  echo "  restart           重启后端"
  echo "  status            运行状态"
  echo "  logs              服务日志(实时)"
  echo "  uninstall         卸载(默认保留数据, 使用 --purge 彻底删除)"
  echo "选项(install/uninstall 可用):"
  echo "  --dir PATH        安装目录, 默认 /opt/SGMessengerBot"
  echo "  --user NAME       运行用户, 默认 sgmessenger"
  echo "  --bot-token VAL   机器人令牌"
  echo "  --owner-id VAL    管理员ID"
  echo "  --group-id VAL    群组ID"
  echo "  --db-name VAL     数据库文件名, 默认 forward_bot.db"
  echo "  --flood-limit N   防洪秒数, 默认 0"
  echo "  --no-enable       安装后不启用开机自启动"
  echo "  --purge           卸载时删除安装目录与用户"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "需要使用 root 权限执行" >&2
    exit 1
  fi
}

ensure_debian() {
  if [ ! -f /etc/os-release ]; then
    echo "无法检测系统版本" >&2
    exit 1
  fi
  . /etc/os-release
  if [ "${ID:-}" != "debian" ]; then
    echo "仅支持 Debian 系统" >&2
    exit 1
  fi
  V="${VERSION_ID:-}" 
  if [ "$V" != "12" ] && [ "$V" != "13" ]; then
    echo "仅支持 Debian 12/13, 当前: $V" >&2
    exit 1
  fi
}

install_deps() {
  apt-get update -y
  apt-get install -y python3 python3-venv python3-pip rsync sqlite3 systemd
}

create_user() {
  if id -u "$RUN_USER" >/dev/null 2>&1; then
    return
  fi
  useradd --system --create-home --home-dir "/var/lib/$SERVICE_NAME" --shell /usr/sbin/nologin "$RUN_USER"
}

setup_project() {
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete --exclude ".git" --exclude ".venv" ./ "$INSTALL_DIR/"
  chown -R "$RUN_USER":"$RUN_USER" "$INSTALL_DIR"
}

setup_venv() {
  "$PYTHON_BIN" -m venv "$INSTALL_DIR/.venv"
  "$INSTALL_DIR/.venv/bin/pip" install --upgrade pip
  if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    "$INSTALL_DIR/.venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"
  fi
}

write_env() {
  BOT_TOKEN_VAL="${BOT_TOKEN_VAL:-}"
  OWNER_ID_VAL="${OWNER_ID_VAL:-}"
  GROUP_ID_VAL="${GROUP_ID_VAL:-}"
  DB_NAME_VAL="${DB_NAME_VAL:-forward_bot.db}"
  FLOOD_LIMIT_VAL="${FLOOD_LIMIT_VAL:-0}"
  cat > "$INSTALL_DIR/.env" <<EOF
BOT_TOKEN=$BOT_TOKEN_VAL
OWNER_ID=$OWNER_ID_VAL
GROUP_ID=$GROUP_ID_VAL
DB_NAME=$DB_NAME_VAL
FLOOD_LIMIT_SECONDS=$FLOOD_LIMIT_VAL
EOF
  chown "$RUN_USER":"$RUN_USER" "$INSTALL_DIR/.env"
}

write_service() {
  cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=SGMessengerBot Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONTRACEMALLOC=1
ExecStart=$INSTALL_DIR/.venv/bin/python $INSTALL_DIR/main.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

do_install() {
  require_root
  ensure_debian
  install_deps
  create_user
  setup_project
  setup_venv
  write_env
  write_service
  systemctl daemon-reload
  if [ "${NO_ENABLE:-0}" -eq 0 ]; then
    systemctl enable "$SERVICE_NAME"
  fi
  systemctl start "$SERVICE_NAME"
  systemctl status "$SERVICE_NAME" --no-pager
}

do_enable() { require_root; systemctl enable "$SERVICE_NAME"; }
do_disable() { require_root; systemctl disable "$SERVICE_NAME"; }
do_start() { require_root; systemctl start "$SERVICE_NAME"; }
do_stop() { require_root; systemctl stop "$SERVICE_NAME"; }
do_restart() { require_root; systemctl restart "$SERVICE_NAME"; }
do_status() { systemctl status "$SERVICE_NAME" --no-pager || true; }
do_logs() { journalctl -u "$SERVICE_NAME" -f; }

do_uninstall() {
  require_root
  systemctl stop "$SERVICE_NAME" || true
  systemctl disable "$SERVICE_NAME" || true
  rm -f "/etc/systemd/system/$SERVICE_NAME.service"
  systemctl daemon-reload
  if [ "${PURGE:-0}" -eq 1 ]; then
    if id -u "$RUN_USER" >/dev/null 2>&1; then
      pkill -u "$RUN_USER" || true
    fi
    rm -rf "$INSTALL_DIR"
    if id -u "$RUN_USER" >/dev/null 2>&1; then
      userdel -r "$RUN_USER" || true
    fi
  fi
  echo "已卸载"
}

CMD="${1:-}"
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2;;
    --user) RUN_USER="$2"; shift 2;;
    --bot-token) BOT_TOKEN_VAL="$2"; shift 2;;
    --owner-id) OWNER_ID_VAL="$2"; shift 2;;
    --group-id) GROUP_ID_VAL="$2"; shift 2;;
    --db-name) DB_NAME_VAL="$2"; shift 2;;
    --flood-limit) FLOOD_LIMIT_VAL="$2"; shift 2;;
    --no-enable) NO_ENABLE=1; shift 1;;
    --purge) PURGE=1; shift 1;;
    *) echo "未知选项: $1"; usage; exit 1;;
  esac
done

case "$CMD" in
  install) do_install;;
  enable) do_enable;;
  disable) do_disable;;
  start) do_start;;
  stop) do_stop;;
  restart) do_restart;;
  status) do_status;;
  logs) do_logs;;
  uninstall) do_uninstall;;
  *) usage; exit 1;;
esac