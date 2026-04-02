/**
 * clawdbot — Pi-powered Telegram bot
 *
 * Bridges Telegram messages to a Pi AgentSession, giving you full
 * coding-agent capabilities (read, bash, edit, write tools) over chat.
 *
 * Environment variables (set by systemd / sops-nix):
 *   TELEGRAM_BOT_TOKEN_FILE    — path to file containing Telegram bot token
 *   ANTHROPIC_API_KEY_FILE     — path to file containing Anthropic API key
 *   ALLOWED_USER_IDS           — comma-separated Telegram user IDs allowed to use the bot
 *   STATE_DIRECTORY            — systemd StateDirectory (defaults to ./state)
 *   WORKING_DIRECTORY          — working directory for the agent (defaults to STATE_DIRECTORY)
 *   CLAWDBOT_MODEL             — Anthropic model ID (default: claude-sonnet-4-5)
 *   SESSION_TIMEOUT_MINUTES    — inactivity timeout before a new session starts (default: 60)
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

// After this many minutes of silence, the next message starts a fresh session.
const SESSION_TIMEOUT_MS =
  parseInt(process.env.SESSION_TIMEOUT_MINUTES ?? "60", 10) * 60_000;

mkdirSync(`${STATE_DIR}/sessions`, { recursive: true });

const START_TIME = Date.now();

// ─── Telegram Bot ─────────────────────────────────────────────────────────────

const bot = new Bot(telegramToken);

// ─── Pi Session management ────────────────────────────────────────────────────

interface ChatState {
  session: AgentSession;
  lastActive: number; // ms timestamp of the last completed prompt
}

const chats = new Map<number, ChatState>();

function formatAge(ms: number): string {
  const m = Math.round(ms / 60_000);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}

async function getOrCreateSession(chatId: number): Promise<AgentSession> {
  const now = Date.now();
  const existing = chats.get(chatId);

  if (existing) {
    const idle = now - existing.lastActive;
    if (idle > SESSION_TIMEOUT_MS) {
      // Too long since last message — start a fresh conversation
      console.log(
        `[clawdbot] [chat=${chatId}] idle for ${formatAge(idle)}, starting new session`,
      );
      await existing.session.newSession();
    }
    return existing.session;
  }

  // First access since startup — resume the most recent session from disk,
  // or create a new one if none exists.
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
    sessionManager: SessionManager.continueRecent(WORKING_DIR, sessionDir),
  });

  // Check whether the resumed session is still within the timeout window.
  // session.messages is the full conversation history; the last message's
  // timestamp tells us when the chat was last active.
  const messages = session.messages;
  const lastMsg = messages[messages.length - 1] as { timestamp?: number } | undefined;
  const lastTimestamp = lastMsg?.timestamp ?? 0;

  if (lastTimestamp > 0) {
    const age = now - lastTimestamp;
    if (age > SESSION_TIMEOUT_MS) {
      console.log(
        `[clawdbot] [chat=${chatId}] resumed session is ${formatAge(age)} old — starting fresh`,
      );
      await session.newSession();
    } else {
      console.log(
        `[clawdbot] [chat=${chatId}] resumed session (last active ${formatAge(age)} ago, ${messages.length} messages)`,
      );
    }
  } else {
    console.log(`[clawdbot] [chat=${chatId}] created new session`);
  }

  chats.set(chatId, { session, lastActive: lastTimestamp > 0 ? lastTimestamp : now });
  return session;
}

function touchSession(chatId: number): void {
  const state = chats.get(chatId);
  if (state) state.lastActive = Date.now();
}

async function resetSession(chatId: number): Promise<void> {
  const state = chats.get(chatId);
  if (state) {
    await state.session.newSession();
    state.lastActive = Date.now();
  }
}

// ─── Text chunking ────────────────────────────────────────────────────────────

const MAX_CHUNK = 4000;

function chunkText(text: string, limit = MAX_CHUNK): string[] {
  if (text.length <= limit) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > limit) {
    let cut = remaining.lastIndexOf("\n\n", limit);
    if (cut < limit / 2) cut = remaining.lastIndexOf("\n", limit);
    if (cut < limit / 2) cut = remaining.lastIndexOf(" ", limit);
    if (cut <= 0) cut = limit;
    chunks.push(remaining.slice(0, cut).trimEnd());
    remaining = remaining.slice(cut).trimStart();
  }

  if (remaining.length > 0) chunks.push(remaining);
  return chunks;
}

// ─── Markdown sanitization ────────────────────────────────────────────────────

function sanitizeForTelegram(text: string): string {
  return text
    .replace(/~~(.*?)~~/g, "$1")
    .replace(/^#{1,6}\s+/gm, "**")
    .replace(/\*{3}(.*?)\*{3}/g, "*$1*");
}

// ─── Auth check ───────────────────────────────────────────────────────────────

function isAllowed(ctx: Context): boolean {
  if (ALLOWED_USER_IDS.size === 0) {
    console.warn("[clawdbot] ALLOWED_USER_IDS is empty — denying all users");
    return false;
  }
  const userId = ctx.from?.id;
  return userId !== undefined && ALLOWED_USER_IDS.has(userId);
}

// ─── Shared prompt runner ─────────────────────────────────────────────────────

async function runPrompt(
  ctx: Context & { chat: { id: number } },
  session: AgentSession,
  text: string,
  options?: { images?: { type: "image"; data: string; mimeType: string }[] },
): Promise<void> {
  const chatId = ctx.chat.id;
  let response = "";

  const unsub = session.subscribe((event) => {
    if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
      response += event.assistantMessageEvent.delta;
    }
  });

  await ctx.replyWithChatAction("typing");
  const typingInterval = setInterval(() => {
    ctx.replyWithChatAction("typing").catch(() => {});
  }, 4_000);

  try {
    await session.prompt(text, options);
    touchSession(chatId);

    const sanitized = sanitizeForTelegram(response.trim());
    if (!sanitized) {
      await ctx.reply("_(no response)_", { parse_mode: "Markdown" });
      return;
    }

    for (const chunk of chunkText(sanitized)) {
      try {
        await ctx.reply(chunk, { parse_mode: "Markdown" });
      } catch {
        await ctx.reply(chunk);
      }
    }

    console.log(`[clawdbot] [chat=${chatId}] replied (${sanitized.length} chars)`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[clawdbot] [chat=${chatId}] error: ${message}`);
    await ctx.reply(`❌ Error: ${message}`);
  } finally {
    clearInterval(typingInterval);
    unsub();
  }
}

// ─── Commands ─────────────────────────────────────────────────────────────────

bot.command("start", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply(
    "👋 Hi, I'm clawdbot — your Pi coding agent on Telegram.\n\n" +
      "Just send me a message and I'll get to work.\n\n" +
      "Commands:\n" +
      "/new — Start a fresh session\n" +
      "/status — Show bot and session status\n" +
      "/chatid — Show your Telegram chat ID\n" +
      "/help — This message",
  );
});

bot.command("help", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply(
    "/start — Introduction\n" +
      "/new — Start a fresh session\n" +
      "/status — Show bot and session status\n" +
      "/chatid — Show your Telegram chat ID\n" +
      "/help — This message",
  );
});

bot.command("chatid", async (ctx) => {
  await ctx.reply(
    `Your chat ID is: \`${ctx.chat.id}\`\nYour user ID is: \`${ctx.from?.id ?? "unknown"}\``,
    { parse_mode: "Markdown" },
  );
});

bot.command("status", async (ctx) => {
  if (!isAllowed(ctx)) return;

  const uptimeMs = Date.now() - START_TIME;
  const hours = Math.floor(uptimeMs / 3_600_000);
  const minutes = Math.floor((uptimeMs % 3_600_000) / 60_000);
  const seconds = Math.floor((uptimeMs % 60_000) / 1_000);

  const state = chats.get(ctx.chat.id);
  const sessionInfo = state
    ? `Last active: ${formatAge(Date.now() - state.lastActive)} ago\nMessages: ${state.session.messages.length}\nTimeout: ${SESSION_TIMEOUT_MS / 60_000}m`
    : "No active session";

  await ctx.reply(
    `✅ *clawdbot running*\n` +
      `Uptime: ${hours}h ${minutes}m ${seconds}s\n` +
      `Model: \`${model.id}\`\n` +
      `Working dir: \`${WORKING_DIR}\`\n\n` +
      `*Session:*\n${sessionInfo}`,
    { parse_mode: "Markdown" },
  );
});

bot.command("new", async (ctx) => {
  if (!isAllowed(ctx)) return;
  await ctx.reply("🔄 Starting a fresh session…");
  try {
    // Ensure session exists then reset it
    await getOrCreateSession(ctx.chat.id);
    await resetSession(ctx.chat.id);
    await ctx.reply("✅ New session started.");
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to reset session: ${message}`);
  }
});

// ─── Message handlers ─────────────────────────────────────────────────────────

bot.on("message:text", async (ctx) => {
  if (!isAllowed(ctx)) return;

  const userText = ctx.message.text;
  if (userText.startsWith("/")) return; // handled by command handlers

  const chatId = ctx.chat.id;
  console.log(`[clawdbot] [chat=${chatId}] user: ${userText.slice(0, 80)}`);

  let session: AgentSession;
  try {
    session = await getOrCreateSession(chatId);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[clawdbot] Failed to get session for chat ${chatId}: ${msg}`);
    await ctx.reply(`❌ Failed to initialise session: ${msg}`);
    return;
  }

  await runPrompt(ctx, session, userText);
});

bot.on("message:photo", async (ctx) => {
  if (!isAllowed(ctx)) return;

  const chatId = ctx.chat.id;
  const caption = ctx.message.caption ?? "What's in this image?";

  let session: AgentSession;
  try {
    session = await getOrCreateSession(chatId);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to initialise session: ${msg}`);
    return;
  }

  const photo = ctx.message.photo[ctx.message.photo.length - 1];

  let imageData: string;
  try {
    const file = await ctx.getFile();
    const fileUrl = `https://api.telegram.org/file/bot${telegramToken}/${file.file_path}`;
    const resp = await fetch(fileUrl);
    imageData = Buffer.from(await resp.arrayBuffer()).toString("base64");
    console.log(`[clawdbot] [chat=${chatId}] photo: ${photo.file_size ?? "?"} bytes`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    await ctx.reply(`❌ Failed to download image: ${msg}`);
    return;
  }

  await runPrompt(ctx, session, caption, {
    images: [{ type: "image", data: imageData, mimeType: "image/jpeg" }],
  });
});

// ─── Graceful shutdown ────────────────────────────────────────────────────────

async function shutdown(signal: string): Promise<void> {
  console.log(`[clawdbot] Received ${signal}, shutting down…`);
  try { await bot.stop(); } catch { /* ignore */ }
  for (const [chatId, { session }] of chats) {
    try { session.dispose(); } catch { /* ignore */ }
    console.log(`[clawdbot] Disposed session for chat ${chatId}`);
  }
  chats.clear();
  process.exit(0);
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

// ─── Start ────────────────────────────────────────────────────────────────────

console.log(
  `[clawdbot] Starting (model: ${model.id}, timeout: ${SESSION_TIMEOUT_MS / 60_000}m, ` +
  `working dir: ${WORKING_DIR}, state dir: ${STATE_DIR})`,
);
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
