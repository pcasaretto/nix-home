/**
 * clawdbot — Pi-powered Telegram bot
 *
 * Bridges Telegram messages to a Pi AgentSession, giving you full
 * coding-agent capabilities (read, bash, edit, write tools) over chat.
 *
 * Environment variables (set by systemd / sops-nix):
 *   TELEGRAM_BOT_TOKEN_FILE  — path to file containing Telegram bot token
 *   ANTHROPIC_API_KEY_FILE   — path to file containing Anthropic API key
 *   ALLOWED_USER_IDS         — comma-separated Telegram user IDs allowed to use the bot
 *   STATE_DIRECTORY          — systemd StateDirectory (defaults to ./state)
 *   WORKING_DIRECTORY        — working directory for the agent (defaults to STATE_DIRECTORY)
 */

import { readFileSync } from "fs";
import { mkdirSync } from "fs";
import { Bot, type Context } from "grammy";
import { getModel } from "@mariozechner/pi-ai";
import {
  AuthStorage,
  createAgentSession,
  createBashTool,
  createEditTool,
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
  createWriteTool,
  ModelRegistry,
  SessionManager,
  SettingsManager,
  type AgentSession,
} from "@mariozechner/pi-coding-agent";

const MODEL_ID = (process.env.CLAWDBOT_MODEL ?? "claude-sonnet-4-5") as Parameters<typeof getModel>[1] & string;
const model = getModel("anthropic", MODEL_ID as never);
if (!model) {
  console.error(`[clawdbot] Unknown model: ${MODEL_ID}`);
  process.exit(1);
}

// ─── Config ──────────────────────────────────────────────────────────────────

function readSecretFile(envVar: string): string {
  const path = process.env[envVar];
  if (!path) {
    console.error(`[clawdbot] ${envVar} is not set`);
    process.exit(1);
  }
  try {
    return readFileSync(path, "utf-8").trim();
  } catch (err) {
    console.error(`[clawdbot] Cannot read secret file ${path}: ${err}`);
    process.exit(1);
  }
}

const telegramToken = readSecretFile("TELEGRAM_BOT_TOKEN_FILE");
const anthropicKey = readSecretFile("ANTHROPIC_API_KEY_FILE");

const ALLOWED_USER_IDS = new Set(
  (process.env.ALLOWED_USER_IDS ?? "")
    .split(",")
    .map((s) => parseInt(s.trim(), 10))
    .filter((n) => !isNaN(n) && n > 0),
);

const STATE_DIR = process.env.STATE_DIRECTORY ?? "./state";
const WORKING_DIR = process.env.WORKING_DIRECTORY ?? STATE_DIR;

// Ensure session directory exists
mkdirSync(`${STATE_DIR}/sessions`, { recursive: true });

const START_TIME = Date.now();

// ─── Telegram Bot ─────────────────────────────────────────────────────────────

const bot = new Bot(telegramToken);

// ─── Pi Session management ────────────────────────────────────────────────────

const sessions = new Map<number, AgentSession>();

async function getOrCreateSession(chatId: number): Promise<AgentSession> {
  if (sessions.has(chatId)) return sessions.get(chatId)!;

  const sessionDir = `${STATE_DIR}/sessions/${chatId}`;
  mkdirSync(sessionDir, { recursive: true });

  const authStorage = AuthStorage.create(`${STATE_DIR}/auth.json`);
  authStorage.setRuntimeApiKey("anthropic", anthropicKey);

  const modelRegistry = new ModelRegistry(authStorage);

  const settingsManager = SettingsManager.inMemory({
    compaction: { enabled: true },
    retry: { enabled: true, maxRetries: 3 },
  });

  const { session } = await createAgentSession({
    cwd: WORKING_DIR,
    model,
    authStorage,
    modelRegistry,
    settingsManager,
    tools: [
      createReadTool(WORKING_DIR),
      createBashTool(WORKING_DIR),
      createEditTool(WORKING_DIR),
      createWriteTool(WORKING_DIR),
      createGrepTool(WORKING_DIR),
      createFindTool(WORKING_DIR),
      createLsTool(WORKING_DIR),
    ],
    sessionManager: SessionManager.create(WORKING_DIR, sessionDir),
  });

  sessions.set(chatId, session);
  console.log(`[clawdbot] Created session for chat ${chatId} (dir: ${sessionDir})`);
  return session;
}

async function resetSession(chatId: number): Promise<void> {
  const existing = sessions.get(chatId);
  if (existing) {
    try {
      await existing.newSession();
    } catch {
      // If newSession fails, remove and recreate on next message
      existing.dispose();
      sessions.delete(chatId);
    }
  }
}

// ─── Text chunking ────────────────────────────────────────────────────────────

const MAX_CHUNK = 4000;

function chunkText(text: string, limit = MAX_CHUNK): string[] {
  if (text.length <= limit) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > limit) {
    // Try to break at a paragraph boundary
    let cut = remaining.lastIndexOf("\n\n", limit);
    if (cut < limit / 2) {
      // Fall back to a newline
      cut = remaining.lastIndexOf("\n", limit);
    }
    if (cut < limit / 2) {
      // Fall back to a space
      cut = remaining.lastIndexOf(" ", limit);
    }
    if (cut <= 0) {
      cut = limit;
    }
    chunks.push(remaining.slice(0, cut).trimEnd());
    remaining = remaining.slice(cut).trimStart();
  }

  if (remaining.length > 0) chunks.push(remaining);
  return chunks;
}

// ─── Markdown sanitization ────────────────────────────────────────────────────
// Telegram MarkdownV2 is strict. We try HTML mode for robustness instead.

function sanitizeForTelegram(text: string): string {
  // Remove unsupported/problematic markdown patterns for Telegram Markdown mode
  // Replace ~~strikethrough~~ and other unsupported syntax
  return text
    .replace(/~~(.*?)~~/g, "$1")   // strikethrough not in basic Markdown
    .replace(/^#{1,6}\s+/gm, "**") // ATX headings → bold prefix (simple)
    .replace(/\*{3}(.*?)\*{3}/g, "*$1*"); // Bold-italic → just italic
}

// ─── Auth check ───────────────────────────────────────────────────────────────

function isAllowed(ctx: Context): boolean {
  if (ALLOWED_USER_IDS.size === 0) {
    // No allowlist configured — warn loudly and deny all
    console.warn("[clawdbot] ALLOWED_USER_IDS is empty — denying all users");
    return false;
  }
  const userId = ctx.from?.id;
  return userId !== undefined && ALLOWED_USER_IDS.has(userId);
}

// ─── Commands ─────────────────────────────────────────────────────────────────

bot.command("start", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply(
    "👋 Hi, I'm clawdbot — your Pi coding agent on Telegram.\n\n" +
      "Just send me a message and I'll get to work.\n\n" +
      "Commands:\n" +
      "/new — Start a fresh session\n" +
      "/status — Show bot status\n" +
      "/chatid — Show your Telegram chat ID\n" +
      "/help — This message",
  );
});

bot.command("help", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply(
    "/start — Introduction\n" +
      "/new — Start a fresh session\n" +
      "/status — Show bot status\n" +
      "/chatid — Show your Telegram chat ID\n" +
      "/help — This message",
  );
});

bot.command("chatid", async (ctx) => {
  await ctx.reply(`Your chat ID is: \`${ctx.chat.id}\`\nYour user ID is: \`${ctx.from?.id ?? "unknown"}\``, {
    parse_mode: "Markdown",
  });
});

bot.command("status", async (ctx) => {
  if (!isAllowed(ctx)) return;
  const uptimeMs = Date.now() - START_TIME;
  const hours = Math.floor(uptimeMs / 3_600_000);
  const minutes = Math.floor((uptimeMs % 3_600_000) / 60_000);
  const seconds = Math.floor((uptimeMs % 60_000) / 1_000);
  const activeSessions = sessions.size;
  await ctx.reply(
    `✅ *clawdbot running*\n` +
      `Uptime: ${hours}h ${minutes}m ${seconds}s\n` +
      `Active sessions: ${activeSessions}\n` +
      `Working dir: \`${WORKING_DIR}\``,
    { parse_mode: "Markdown" },
  );
});

bot.command("new", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply("🔄 Starting a fresh session…");
  try {
    await resetSession(ctx.chat.id);
    await ctx.reply("✅ New session started.");
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to reset session: ${message}`);
  }
});

// ─── Main message handler ─────────────────────────────────────────────────────

bot.on("message:text", async (ctx) => {
  if (!isAllowed(ctx)) return;

  const chatId = ctx.chat.id;
  const userText = ctx.message.text;

  // Skip messages that are commands (already handled above)
  if (userText.startsWith("/")) return;

  console.log(`[clawdbot] [chat=${chatId}] user: ${userText.slice(0, 80)}`);

  let session: AgentSession;
  try {
    session = await getOrCreateSession(chatId);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[clawdbot] Failed to create session for chat ${chatId}: ${message}`);
    await ctx.reply(`❌ Failed to initialise session: ${message}`);
    return;
  }

  // Accumulate streamed response
  let response = "";
  const unsub = session.subscribe((event) => {
    if (
      event.type === "message_update" &&
      event.assistantMessageEvent.type === "text_delta"
    ) {
      response += event.assistantMessageEvent.delta;
    }
  });

  // Send typing indicator every 4 s while the agent is working
  await ctx.replyWithChatAction("typing");
  const typingInterval = setInterval(() => {
    ctx.replyWithChatAction("typing").catch(() => {});
  }, 4_000);

  try {
    await session.prompt(userText);

    const text = sanitizeForTelegram(response.trim());
    if (!text) {
      await ctx.reply("_(no response)_", { parse_mode: "Markdown" });
      return;
    }

    const chunks = chunkText(text);
    for (const chunk of chunks) {
      try {
        await ctx.reply(chunk, { parse_mode: "Markdown" });
      } catch {
        // If Markdown parse fails, fall back to plain text
        await ctx.reply(chunk);
      }
    }

    console.log(`[clawdbot] [chat=${chatId}] replied (${text.length} chars, ${chunks.length} chunk(s))`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[clawdbot] [chat=${chatId}] error: ${message}`);
    await ctx.reply(`❌ Error: ${message}`);
  } finally {
    clearInterval(typingInterval);
    unsub();
  }
});

// ─── Photo handler ────────────────────────────────────────────────────────────

bot.on("message:photo", async (ctx) => {
  if (!isAllowed(ctx)) return;

  const chatId = ctx.chat.id;
  const caption = ctx.message.caption ?? "What's in this image?";

  let session: AgentSession;
  try {
    session = await getOrCreateSession(chatId);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to initialise session: ${message}`);
    return;
  }

  // Get the highest-resolution photo
  const photos = ctx.message.photo;
  const photo = photos[photos.length - 1];

  let imageData: string;
  let mediaType: "image/jpeg" | "image/png" | "image/gif" | "image/webp";

  try {
    const file = await ctx.getFile();
    const fileUrl = `https://api.telegram.org/file/bot${telegramToken}/${file.file_path}`;
    const resp = await fetch(fileUrl);
    const buf = await resp.arrayBuffer();
    imageData = Buffer.from(buf).toString("base64");
    // Telegram photos are always JPEG unless otherwise specified
    mediaType = "image/jpeg";
    console.log(`[clawdbot] [chat=${chatId}] photo: ${photo.file_size ?? "?"} bytes, file_id=${photo.file_id}`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to download image: ${message}`);
    return;
  }

  let response = "";
  const unsub = session.subscribe((event) => {
    if (
      event.type === "message_update" &&
      event.assistantMessageEvent.type === "text_delta"
    ) {
      response += event.assistantMessageEvent.delta;
    }
  });

  await ctx.replyWithChatAction("typing");
  const typingInterval = setInterval(() => {
    ctx.replyWithChatAction("typing").catch(() => {});
  }, 4_000);

  try {
    await session.prompt(caption, {
      images: [{ type: "image", data: imageData, mimeType: mediaType }],
    });

    const text = sanitizeForTelegram(response.trim());
    const chunks = chunkText(text || "_(no response)_");
    for (const chunk of chunks) {
      try {
        await ctx.reply(chunk, { parse_mode: "Markdown" });
      } catch {
        await ctx.reply(chunk);
      }
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Error: ${message}`);
  } finally {
    clearInterval(typingInterval);
    unsub();
  }
});

// ─── Graceful shutdown ────────────────────────────────────────────────────────

async function shutdown(signal: string): Promise<void> {
  console.log(`[clawdbot] Received ${signal}, shutting down…`);
  try {
    await bot.stop();
  } catch {
    // ignore
  }
  for (const [chatId, session] of sessions) {
    try {
      session.dispose();
    } catch {
      // ignore
    }
    console.log(`[clawdbot] Disposed session for chat ${chatId}`);
  }
  sessions.clear();
  process.exit(0);
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

// ─── Start ────────────────────────────────────────────────────────────────────

console.log(`[clawdbot] Starting (model: ${model.id}, working dir: ${WORKING_DIR}, state dir: ${STATE_DIR})`);
if (ALLOWED_USER_IDS.size > 0) {
  console.log(`[clawdbot] Allowed user IDs: ${[...ALLOWED_USER_IDS].join(", ")}`);
} else {
  console.warn("[clawdbot] WARNING: ALLOWED_USER_IDS is empty — all users will be denied");
}

bot.start({
  onStart: (info) => {
    console.log(`[clawdbot] Bot @${info.username} started (long polling)`);
  },
});
