# Telegram转发机器人主程序
import logging
from typing import Optional
import signal
import sys

from telegram import BotCommand, BotCommandScopeChat
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters
)
from telegram.error import Forbidden

from config import Config
from database import Database
from handlers import (
    start,
    verify_user,
    handle_user_message,
    handle_admin_reply,
    handle_group_message,
    broadcast_command,
    handle_broadcast_content,
    execute_broadcast
)

# 配置日志
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)


async def post_init(application: Application) -> None:
    """机器人初始化后设置命令菜单和启动通知"""
    try:
        admin_commands = [BotCommand("start", "启动菜单")]
        await application.bot.set_my_commands(
            admin_commands,
            scope=BotCommandScopeChat(chat_id=Config.OWNER_ID)
        )
        logger.info("管理员命令菜单设置成功")
    except Exception as e:
        logger.error(f"设置管理员命令菜单失败: {e}")
    try:
        await application.bot.send_message(
            chat_id=Config.OWNER_ID,
            text="🤖 机器人已成功启动！"
        )
        logger.info("启动通知已发送给管理员")
    except Forbidden as e:
        logger.warning(f"无法向管理员发送启动通知: {e}")
        logger.info("这是正常现象，管理员需要先向机器人发送消息才能接收通知")
    except Exception as e:
        logger.error(f"发送启动通知失败: {e}")


def setup_handlers(application: Application) -> None:
    """注册所有消息处理器"""
    private_chat_filter = filters.ChatType.PRIVATE
    group_chat_filter = filters.ChatType.SUPERGROUP | filters.ChatType.GROUP
    application.add_handler(CommandHandler("start", start, filters=private_chat_filter))
    application.add_handler(CallbackQueryHandler(verify_user, pattern="^verify$"))
    application.add_handler(MessageHandler(
        filters.Regex("^全体广播$") & filters.User(Config.OWNER_ID) & private_chat_filter, 
        broadcast_command
    ))
    application.add_handler(MessageHandler(
        filters.REPLY & filters.User(Config.OWNER_ID) & private_chat_filter, 
        handle_admin_reply
    ))
    application.add_handler(MessageHandler(
        filters.ALL & filters.User(Config.OWNER_ID) & ~filters.COMMAND & private_chat_filter, 
        handle_broadcast_content
    ))
    application.add_handler(MessageHandler(
        filters.ALL & ~filters.COMMAND & ~filters.User(Config.OWNER_ID) & private_chat_filter, 
        handle_user_message
    ))
    application.add_handler(CallbackQueryHandler(
        execute_broadcast, 
        pattern="^(confirm|cancel)_broadcast$"
    ))
    application.add_handler(MessageHandler(
        filters.Chat(Config.GROUP_ID) & filters.User(Config.OWNER_ID) & group_chat_filter,
        handle_group_message
    ))


def main() -> None:
    """主函数，启动机器人"""
    Config.validate()
    if not isinstance(Config.BOT_TOKEN, str) or not Config.BOT_TOKEN:
        raise ValueError("Config.BOT_TOKEN 必须为非空字符串")
    application = Application.builder() \
        .token(Config.BOT_TOKEN) \
        .post_init(post_init) \
        .build()
    # 挂载依赖实例
    application.bot_data['db'] = Database()
    from flood_control import FloodControl
    application.bot_data['flood_control'] = FloodControl()
    setup_handlers(application)
    logger.info("机器人开始运行...")

    def graceful_exit(signum, frame):
        logger.info(f"收到信号 {signum}，正在优雅关闭...")
        application.bot_data['db'].close()
        logger.info("数据库已关闭，程序退出。")
        sys.exit(0)

    signal.signal(signal.SIGINT, graceful_exit)
    signal.signal(signal.SIGTERM, graceful_exit)

    try:
        application.run_polling(drop_pending_updates=True)
    except Exception:
        logger.exception("机器人运行失败")
    finally:
        application.bot_data['db'].close()
        logger.info("机器人已停止")


if __name__ == "__main__":
    main()

