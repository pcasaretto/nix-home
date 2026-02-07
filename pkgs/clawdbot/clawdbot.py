#!/usr/bin/env python3
"""clawdbot - A Telegram bot for notifications and future AI interactions."""

import logging
import os
import sys
from datetime import datetime, timezone

from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

START_TIME = datetime.now(timezone.utc)


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "Hey, I'm clawdbot. Use /help to see what I can do."
    )


async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "/start  - Introduction\n"
        "/help   - This message\n"
        "/chatid - Show your chat ID (for notification setup)\n"
        "/status - Bot status"
    )


async def cmd_chatid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    await update.message.reply_text(f"Your chat ID is: `{chat_id}`", parse_mode="Markdown")


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    uptime = datetime.now(timezone.utc) - START_TIME
    hours, remainder = divmod(int(uptime.total_seconds()), 3600)
    minutes, seconds = divmod(remainder, 60)
    await update.message.reply_text(
        f"Status: running\n"
        f"Uptime: {hours}h {minutes}m {seconds}s"
    )


def main() -> None:
    token_file = os.environ.get("TELEGRAM_BOT_TOKEN_FILE")
    if not token_file:
        logger.error("TELEGRAM_BOT_TOKEN_FILE environment variable not set")
        sys.exit(1)

    try:
        with open(token_file) as f:
            token = f.read().strip()
    except FileNotFoundError:
        logger.error("Token file not found: %s", token_file)
        sys.exit(1)

    if not token:
        logger.error("Token file is empty: %s", token_file)
        sys.exit(1)

    app = Application.builder().token(token).build()

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("help", cmd_help))
    app.add_handler(CommandHandler("chatid", cmd_chatid))
    app.add_handler(CommandHandler("status", cmd_status))

    logger.info("Starting clawdbot with long polling")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
