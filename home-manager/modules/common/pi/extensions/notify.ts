/**
 * Notify User Extension
 *
 * Registers a `notify_user` tool that agents call explicitly when they need
 * the user's attention. Does NOT fire automatically on every turn.
 *
 * Use cases:
 *   1. A command was blocked (e.g. by safety-net) and the user must intervene
 *   2. A significant piece of work is complete and the user should review it
 *
 * Supported terminals:
 *   - iTerm2           — OSC 9
 *   - Ghostty & others — OSC 777
 *   - WezTerm          — OSC 777 with ST terminator
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";

const sendDesktopNotification = (title: string, body: string): void => {
	const termProgram = process.env.TERM_PROGRAM;
	let payload: string;

	if (termProgram === "iTerm.app") {
		payload = `\x1b]9;${title}: ${body}\x07`;
	} else if (termProgram === "WezTerm") {
		payload = `\x1b]777;notify;${title};${body}\x1b\\`;
	} else {
		payload = `\x1b]777;notify;${title};${body}\x07`;
	}

	try {
		const fs = require("node:fs");
		const ttyFd = fs.openSync("/dev/tty", "w");
		fs.writeSync(ttyFd, payload);
		fs.closeSync(ttyFd);
	} catch {
		try {
			process.stdout.write(payload);
		} catch {
			process.stderr.write(payload);
		}
	}
};

interface NotifyDetails {
	title: string;
	body: string;
	urgency: "info" | "action_needed";
}

const NotifyUserParams = Type.Object({
	body: Type.String({ description: "What to tell the user. Be concise and specific." }),
	title: Type.Optional(Type.String({ description: 'Notification title. Defaults to "pi".' })),
	urgency: Type.Optional(
		StringEnum(["info", "action_needed"] as const, {
			description:
				'"action_needed" when the user must do something (e.g. run a blocked command). "info" when work is complete.',
		}),
	),
});

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "notify_user",
		label: "Notify User",
		description: "Send a desktop notification to get the user's attention.",
		promptGuidelines: [
			"Use notify_user ONLY when the user genuinely needs to act or be informed of a major milestone.",
			"Use urgency='action_needed' when a command was blocked and the user must run it manually.",
			"Use urgency='info' when a significant piece of work is complete (e.g. a multi-step refactor, a long build, a review).",
			"Do NOT use it after routine turns, small edits, or intermediate steps.",
			"Do NOT use it just because you are waiting for the user — they can see the conversation.",
		],
		parameters: NotifyUserParams,

		async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
			const title = params.title ?? "pi";
			const urgency = params.urgency ?? "info";
			const body = params.body;

			sendDesktopNotification(title, body);

			return {
				content: [{ type: "text", text: `Notification sent: "${body}"` }],
				details: { title, body, urgency } as NotifyDetails,
			};
		},

		renderCall(args, theme) {
			const urgency = args.urgency ?? "info";
			const icon = urgency === "action_needed" ? "⚠️" : "🔔";
			let text = theme.fg("toolTitle", theme.bold(`notify_user `));
			text += theme.fg("muted", `${icon} `);
			text += theme.fg("text", args.body ?? "");
			if (args.title) {
				text += theme.fg("dim", `  [${args.title}]`);
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as NotifyDetails | undefined;
			if (!details) {
				return new Text(theme.fg("success", "✓ Notification sent"), 0, 0);
			}
			const icon = details.urgency === "action_needed" ? "⚠️" : "🔔";
			return new Text(
				theme.fg("success", "✓ ") + theme.fg("muted", `${icon} sent: `) + theme.fg("accent", details.body),
				0,
				0,
			);
		},
	});
}
