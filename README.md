# SGMessengerBot - Telegram 转发机器人

一个简单的 Telegram 机器人，用于将用户消息转发给管理员，管理员可以回复消息转发给用户。

---

## ✨ 功能特点

- 📩 消息转发：将用户消息转发给管理员  
- 🔁 管理员回复：支持管理员回复用户消息  
- ✅ 用户验证：防止机器人滥用  
- 🧵 话题管理：在群组中为每个用户创建独立话题  
- 📢 全体广播：管理员可向所有用户发送广播消息  

---

## 🚀 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 配置机器人

复制配置文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入如下配置：

```env
# 从 @BotFather 获取
BOT_TOKEN=你的机器人Token

# 从 @userinfobot 获取
OWNER_ID=你的用户ID

# 论坛群组ID（需要先创建论坛群组）
GROUP_ID=群组ID
```

---

## 🔧 准备工作

### 创建机器人

1. 找到 [@BotFather](https://t.me/BotFather)  
2. 发送 `/newbot` 创建机器人  
3. 获取 Bot Token

### 获取用户 ID

1. 使用 [IDBot](https://t.me/username_to_id_bot)  
2. 获取自己的 ID 和群 ID

### 创建论坛群组

1. 创建新群组  
2. 在群组设置中启用「话题」功能  
3. 将机器人添加为管理员  
4. 给机器人「管理话题」权限  

---

## ▶️ 运行机器人

```bash
python main.py
```



## 📚 Debian 12/13 一键安装

### 核心说明：

- 安装脚本 scripts/sgbotctl.sh ，在 Debian 12/13 上统一完成安装、开机自启、启停、状态、日志与卸载。
- 脚本会创建 systemd 服务，使用虚拟环境安装依赖，并在安装目录加载 .env 配置。

### 安装与配置：

##### 先将项目上传到服务器并进入项目根目录，然后执行安装：

- 基础安装（默认安装到 /opt/SGMessengerBot ，运行用户 sgmessenger ，安装后自动启用开机自启并启动）：
  
  ```
  sudo bash scripts/sgbotctl.sh install --bot-token 你的BOT_TOKEN --owner-id 你的OWNER_ID --group-id 你的GROUP_ID
  ```
- 自定义安装目录与用户：
  
  ```
  sudo bash scripts/sgbotctl.sh install --dir /opt/sgbot --user sgbot --bot-token <TOKEN> --owner-id <ID> --group-id <ID>
  ```
- 设置数据库文件名与防洪秒数：
  
  ```
  sudo bash scripts/sgbotctl.sh install --db-name forward_bot.db --flood-limit 2 --bot-token <TOKEN> --owner-id <ID> --group-id <ID>
  ```
- 安装但不启用开机自启：
  
  ```
  sudo bash scripts/sgbotctl.sh install --no-enable --bot-token <TOKEN> --owner-id <ID> --group-id <ID>
  ```

##### .env 会写入到安装目录，键包含：

- BOT_TOKEN 、 OWNER_ID 、 GROUP_ID 、 DB_NAME 、 FLOOD_LIMIT_SECONDS

##### 依赖安装与运行说明：：

- **脚本会自动安装** python3 、 python3-venv 、 python3-pip 、 sqlite3 、 rsync 、 systemd
- **虚拟环境位于** INSTALL_DIR/.venv ，依赖来自 requirements.txt ：
  - python-telegram-bot==22.1 、 python-dotenv==1.0.0 （ requirements.txt:1-2 ）
- **入口为 main.py** ，会在服务内执行（ main.py:94-129 ）；配置加载自 .env （ config.py:8-18 ）

#### 服务管理

- 设置开机自启动： sudo bash scripts/sgbotctl.sh enable

- 禁用服务开机启动： sudo bash scripts/sgbotctl.sh disable

- 启动后端： sudo bash scripts/sgbotctl.sh start

- 关闭后端： sudo bash scripts/sgbotctl.sh stop

- 重启后端： sudo bash scripts/sgbotctl.sh restart

- 运行状态： bash scripts/sgbotctl.sh status

- 服务日志（实时）： bash scripts/sgbotctl.sh logs

- 标准卸载（保留安装目录与数据）： sudo bash scripts/sgbotctl.sh uninstall

- 彻底卸载（删除安装目录与运行用户）： sudo bash scripts/sgbotctl.sh uninstall --purge
运行原理

- 服务文件路径： /etc/systemd/system/sgmessengerbot.service

- 服务关键配置：
  - WorkingDirectory 为安装目录，确保 .env 被正确加载（ config.py:8-18 ）
  - ExecStart 运行 INSTALL_DIR/.venv/bin/python INSTALL_DIR/main.py （ main.py:94-103 ）
  - 正常启停时，主程序会优雅关闭并释放数据库连接（ main.py:110-126 ）
  
- 数据库：默认使用 sqlite3 ，文件名来自 .env 的 DB_NAME （ database.py:13-17 ）
脚本位置

- 新增文件： scripts/sgbotctl.sh

  #### 功能对照

- 安装脚本： install

- 设置开机自启动： enable

- 禁用服务开机启动： disable

- 启动后端： start

- 关闭后端： stop

- 重启后端： restart

- 运行状态： status

- 服务日志： logs

- 卸载： uninstall （支持 --purge ）
建议与注意

- 首次安装请务必提供 BOT_TOKEN 、 OWNER_ID 、 GROUP_ID ，否则主程序配置校验会失败（ config.py:20-33 ）

- 若群组未配置为论坛或机器人权限不足，创建话题会失败，请检查群设置与机器人权限（ handlers.py:117-127 ）

- 安装完成后，管理员会收到“机器人已成功启动”提示（ main.py:50-57 ）

## 📄 许可证

MIT License
