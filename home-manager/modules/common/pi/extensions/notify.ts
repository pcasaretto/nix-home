/**
 * Desktop Notification Extension
 *
 * Sends a native desktop notification when the agent finishes and is waiting
 * for input. Writes escape sequences via /dev/tty to bypass pi's TUI.
 *
 * Supported terminals:
 *   - iTerm2           — OSC 9 (notification text)
 *   - Ghostty & others — OSC 777 (notify;title;body)
 *
 * Requires: notifications enabled in macOS System Settings for your terminal.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const notify = (title: string, body: string): void => {
	const isITerm = process.env.TERM_PROGRAM === "iTerm.app";
	const payload = isITerm
		? `\x1b]9;${title}: ${body}\x07`       // OSC 9  — iTerm2
		: `\x1b]777;notify;${title};${body}\x07`; // OSC 777 — Ghostty and others

	try {
		const fs = require("node:fs");
		const ttyFd = fs.openSync("/dev/tty", "w");
		fs.writeSync(ttyFd, payload);
		fs.closeSync(ttyFd);
	} catch {
		// Fallback if /dev/tty unavailable
		process.stderr.write(payload);
	}
};

const isTextPart = (part: unknown): part is { type: "text"; text: string } =>
	Boolean(part && typeof part === "object" && "type" in part && part.type === "text" && "text" in part);

const extractLastAssistantText = (messages: Array<{ role?: string; content?: unknown }>): string | null => {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg?.role !== "assistant") continue;

		const content = msg.content;
		if (typeof content === "string") return content.trim() || null;
		if (Array.isArray(content)) {
			const text = content.filter(isTextPart).map((p) => p.text).join("\n").trim();
			return text || null;
		}
		return null;
	}
	return null;
};

const summarize = (text: string | null): string => {
	if (!text) return "Ready for input";
	const plain = text.replace(/[#*_`~\[\]()>|-]/g, "").replace(/\s+/g, " ").trim();
	const max = 200;
	return plain.length > max ? `${plain.slice(0, max - 1)}…` : plain;
};

export default function (pi: ExtensionAPI) {
	pi.on("agent_end", async (event) => {
		const lastText = extractLastAssistantText(event.messages ?? []);
		notify("π", summarize(lastText));
	});
}
