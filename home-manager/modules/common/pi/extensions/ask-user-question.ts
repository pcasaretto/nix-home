/**
 * Ask User Question - Interactive tool for gathering user input
 *
 * Mirrors Claude's ask_user_question tool:
 * - With no options: shows a free-text input prompt
 * - With options: shows a selection list (optionally allowing a custom answer)
 * - With options + multiSelect: shows a checkbox list for multiple selections
 * - Returns the user's response so the agent can continue
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const NOTIFICATION_DELAY_MS = 5_000;

/** Word-wrap text to fit within a given width, preserving explicit newlines. */
function wrapText(text: string, width: number): string[] {
	const result: string[] = [];
	for (const paragraph of text.split("\n")) {
		if (paragraph.length === 0) {
			result.push("");
			continue;
		}
		const words = paragraph.split(/\s+/);
		let currentLine = "";
		for (const word of words) {
			if (currentLine.length === 0) {
				currentLine = word;
			} else if (currentLine.length + 1 + word.length <= width) {
				currentLine += " " + word;
			} else {
				result.push(currentLine);
				currentLine = word;
			}
		}
		if (currentLine.length > 0) {
			result.push(currentLine);
		}
	}
	return result;
}

interface AskDetails {
	question: string;
	options: string[] | null;
	allowCustomAnswer: boolean;
	multiSelect: boolean;
	answer: string | null;
	selectedOptions: string[] | null;
	wasCustom: boolean;
}

const AskUserQuestionParams = Type.Object({
	question: Type.String({ description: "The question to ask the user" }),
	options: Type.Optional(
		Type.Array(Type.String(), {
			description: "Options for the user to choose from. If omitted, shows a free-text input.",
		}),
	),
	allowCustomAnswer: Type.Optional(
		Type.Boolean({
			description:
				'When options are provided, whether to also allow a free-text answer. Adds a "Type your own answer..." choice. Defaults to true.',
		}),
	),
	multiSelect: Type.Optional(
		Type.Boolean({
			description:
				'When options are provided, whether to allow selecting multiple options (checkbox style). Defaults to false. When true, allowCustomAnswer is ignored.',
		}),
	),
});

export default function askUserQuestion(pi: ExtensionAPI) {
	// Inject a one-time persistent message at session start
	pi.on("session_start", async (_event, _ctx) => {
		pi.sendMessage(
			{
				customType: "ask-user-question-reminder",
				content:
					"## IMPORTANT: Asking Questions\n" +
					"NEVER ask the user a question by writing it in your text response. " +
					"ALWAYS use the `ask_user_question` tool to ask questions interactively. " +
					"This gives the user a proper interactive UI to respond. " +
					"This applies to ALL questions: clarifications, preferences, decisions, confirmations, choices — everything. " +
					"The only exception is rhetorical questions that don't need an answer.",
				display: false,
			},
			{ deliverAs: "nextTurn" },
		);
	});

	pi.registerTool({
		name: "ask_user_question",
		label: "Ask User",
		description:
			"Ask the user a question interactively. ALWAYS use this tool instead of writing questions in your response text. With no options: free-text input. With options: selection list (optionally allowing a custom answer). With options + multiSelect: checkbox list for multiple selections.",
		promptGuidelines: [
			"ALWAYS use ask_user_question to ask the user anything — never write questions in your text response.",
			"This is the ONLY way to ask questions. Inline questions in text responses are forbidden.",
			"When a request is ambiguous, has multiple valid interpretations, or you need specific details before proceeding, use this tool.",
			"Don't overuse it — if the user's intent is clear, just proceed without asking.",
			"Use multiSelect: true when the user should be able to choose multiple options (checkbox style). Defaults to single-select.",
		],
		parameters: AskUserQuestionParams,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const allowCustom = params.allowCustomAnswer ?? true;
			const multiSelect = params.multiSelect ?? false;
			const hasOptions = params.options && params.options.length > 0;

			// Non-interactive fallback
			if (!ctx.hasUI) {
				return {
					content: [{ type: "text", text: "Error: UI not available (running in non-interactive mode)" }],
					details: {
						question: params.question,
						options: params.options ?? null,
						allowCustomAnswer: allowCustom,
						multiSelect,
						answer: null,
						selectedOptions: null,
						wasCustom: false,
					} as AskDetails,
				};
			}

			// --- Free-text mode (no options) ---
			if (!hasOptions) {
				const answer = await ctx.ui.custom<string | null>((tui, theme, _kb, rawDone) => {
					let cachedLines: string[] | undefined;

					// Notification timer: nudge user after 5s of inactivity
					const notifyTimer = setTimeout(() => {
						pi.events.emit("notify:desktop", { title: "pi", body: "Agent is waiting for your input" });
					}, NOTIFICATION_DELAY_MS);
					const done = (value: string | null) => {
						clearTimeout(notifyTimer);
						rawDone(value);
					};

					const editorTheme: EditorTheme = {
						borderColor: (s) => theme.fg("accent", s),
					};
					const editor = new Editor(tui, editorTheme);

					editor.onSubmit = (value) => {
						const trimmed = value.trim();
						if (trimmed) {
							done(trimmed);
						}
					};

					function refresh() {
						cachedLines = undefined;
						tui.requestRender();
					}

					function handleInput(data: string) {
						if (matchesKey(data, Key.escape)) {
							done(null);
							return;
						}
						editor.handleInput(data);
						refresh();
					}

					function render(width: number): string[] {
						if (cachedLines) return cachedLines;

						const lines: string[] = [];
						const add = (s: string) => lines.push(truncateToWidth(s, width));

						add(theme.fg("accent", "─".repeat(width)));
						for (const qLine of wrapText(params.question, width - 2)) {
							add(theme.fg("text", ` ${qLine}`));
						}
						lines.push("");
						add(theme.fg("muted", " Your answer:"));
						for (const line of editor.render(width - 2)) {
							add(` ${line}`);
						}
						lines.push("");
						add(theme.fg("dim", " Enter to submit • Esc to cancel"));
						add(theme.fg("accent", "─".repeat(width)));

						cachedLines = lines;
						return lines;
					}

					return {
						render,
						invalidate: () => {
							cachedLines = undefined;
						},
						handleInput,
					};
				});

				if (!answer) {
					return {
						content: [{ type: "text", text: "User cancelled without answering." }],
						details: {
							question: params.question,
							options: null,
							allowCustomAnswer: allowCustom,
							multiSelect: false,
							answer: null,
							selectedOptions: null,
							wasCustom: false,
						} as AskDetails,
					};
				}

				return {
					content: [{ type: "text", text: `User answered: ${answer}` }],
					details: {
						question: params.question,
						options: null,
						allowCustomAnswer: allowCustom,
						multiSelect: false,
						answer,
						selectedOptions: null,
						wasCustom: true,
					} as AskDetails,
				};
			}

			// --- Multi-select mode (checkboxes) ---
			if (multiSelect) {
				const multiResult = await ctx.ui.custom<{ selectedOptions: string[] } | null>(
					(tui, theme, _kb, rawDone) => {
						let optionIndex = 0;
						const checked = new Set<number>();
						let cachedLines: string[] | undefined;

						// Notification timer: nudge user after 5s of inactivity
						const notifyTimer = setTimeout(() => {
							pi.events.emit("notify:desktop", {
								title: "pi",
								body: "Agent is waiting for your input",
							});
						}, NOTIFICATION_DELAY_MS);
						const done = (value: { selectedOptions: string[] } | null) => {
							clearTimeout(notifyTimer);
							rawDone(value);
						};

						function refresh() {
							cachedLines = undefined;
							tui.requestRender();
						}

						function handleInput(data: string) {
							if (matchesKey(data, Key.up)) {
								optionIndex = Math.max(0, optionIndex - 1);
								refresh();
								return;
							}
							if (matchesKey(data, Key.down)) {
								optionIndex = Math.min(params.options!.length - 1, optionIndex + 1);
								refresh();
								return;
							}

							// Space to toggle current option
							if (data === " ") {
								if (checked.has(optionIndex)) {
									checked.delete(optionIndex);
								} else {
									checked.add(optionIndex);
								}
								refresh();
								return;
							}

							// Enter to submit
							if (matchesKey(data, Key.enter)) {
								const selectedOptions = params.options!.filter((_, i) => checked.has(i));
								done({ selectedOptions });
								return;
							}

							// 'a' to toggle all
							if (data === "a" || data === "A") {
								if (checked.size === params.options!.length) {
									checked.clear();
								} else {
									params.options!.forEach((_, i) => checked.add(i));
								}
								refresh();
								return;
							}

							// Number keys for quick toggle (1-9)
							const num = parseInt(data, 10);
							if (num >= 1 && num <= params.options!.length && num <= 9) {
								const idx = num - 1;
								if (checked.has(idx)) {
									checked.delete(idx);
								} else {
									checked.add(idx);
								}
								refresh();
								return;
							}

							if (matchesKey(data, Key.escape)) {
								done(null);
							}
						}

						function render(width: number): string[] {
							if (cachedLines) return cachedLines;

							const lines: string[] = [];
							const add = (s: string) => lines.push(truncateToWidth(s, width));

							add(theme.fg("accent", "─".repeat(width)));
							for (const qLine of wrapText(params.question, width - 2)) {
								add(theme.fg("text", ` ${qLine}`));
							}
							lines.push("");

							for (let i = 0; i < params.options!.length; i++) {
								const isCursor = i === optionIndex;
								const isChecked = checked.has(i);
								const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
								const checkbox = isChecked
									? theme.fg("success", "[✓]")
									: theme.fg("muted", "[ ]");
								const label = `${i + 1}. ${params.options![i]}`;

								if (isCursor) {
									add(prefix + checkbox + " " + theme.fg("accent", label));
								} else {
									add(prefix + checkbox + " " + theme.fg("text", label));
								}
							}

							lines.push("");
							const selectedCount = checked.size;
							if (selectedCount > 0) {
								add(theme.fg("muted", ` ${selectedCount} selected`));
							}
							add(
								theme.fg(
									"dim",
									" Space toggle • a toggle all • 1-9 quick toggle • Enter submit • Esc cancel",
								),
							);
							add(theme.fg("accent", "─".repeat(width)));

							cachedLines = lines;
							return lines;
						}

						return {
							render,
							invalidate: () => {
								cachedLines = undefined;
							},
							handleInput,
						};
					},
				);

				if (!multiResult) {
					return {
						content: [{ type: "text", text: "User cancelled the selection." }],
						details: {
							question: params.question,
							options: params.options ?? null,
							allowCustomAnswer: allowCustom,
							multiSelect: true,
							answer: null,
							selectedOptions: [],
							wasCustom: false,
						} as AskDetails,
					};
				}

				if (multiResult.selectedOptions.length === 0) {
					return {
						content: [{ type: "text", text: "User submitted with no options selected." }],
						details: {
							question: params.question,
							options: params.options ?? null,
							allowCustomAnswer: allowCustom,
							multiSelect: true,
							answer: null,
							selectedOptions: [],
							wasCustom: false,
						} as AskDetails,
					};
				}

				const answerText = multiResult.selectedOptions.join(", ");
				return {
					content: [{ type: "text", text: `User selected: ${answerText}` }],
					details: {
						question: params.question,
						options: params.options ?? null,
						allowCustomAnswer: allowCustom,
						multiSelect: true,
						answer: answerText,
						selectedOptions: multiResult.selectedOptions,
						wasCustom: false,
					} as AskDetails,
				};
			}

			// --- Selection mode (with options) ---
			const displayOptions = [...params.options!];
			if (allowCustom) {
				displayOptions.push("Type your own answer...");
			}

			const result = await ctx.ui.custom<{ answer: string; wasCustom: boolean } | null>(
				(tui, theme, _kb, rawDone) => {
					let optionIndex = 0;
					let editMode = false;
					let cachedLines: string[] | undefined;

					// Notification timer: nudge user after 5s of inactivity
					const notifyTimer = setTimeout(() => {
						pi.events.emit("notify:desktop", { title: "pi", body: "Agent is waiting for your input" });
					}, NOTIFICATION_DELAY_MS);
					const done = (value: { answer: string; wasCustom: boolean } | null) => {
						clearTimeout(notifyTimer);
						rawDone(value);
					};

					const editorTheme: EditorTheme = {
						borderColor: (s) => theme.fg("accent", s),
					};
					const editor = new Editor(tui, editorTheme);

					editor.onSubmit = (value) => {
						const trimmed = value.trim();
						if (trimmed) {
							done({ answer: trimmed, wasCustom: true });
						} else {
							editMode = false;
							editor.setText("");
							refresh();
						}
					};

					function refresh() {
						cachedLines = undefined;
						tui.requestRender();
					}

					function handleInput(data: string) {
						if (editMode) {
							if (matchesKey(data, Key.escape)) {
								editMode = false;
								editor.setText("");
								refresh();
								return;
							}
							editor.handleInput(data);
							refresh();
							return;
						}

						if (matchesKey(data, Key.up)) {
							optionIndex = Math.max(0, optionIndex - 1);
							refresh();
							return;
						}
						if (matchesKey(data, Key.down)) {
							optionIndex = Math.min(displayOptions.length - 1, optionIndex + 1);
							refresh();
							return;
						}

						if (matchesKey(data, Key.enter)) {
							const isCustomOption = allowCustom && optionIndex === displayOptions.length - 1;
							if (isCustomOption) {
								editMode = true;
								refresh();
							} else {
								done({ answer: displayOptions[optionIndex], wasCustom: false });
							}
							return;
						}

						// Number keys for quick selection (1-9)
						const num = parseInt(data, 10);
						if (num >= 1 && num <= displayOptions.length) {
							const isCustomOption = allowCustom && num === displayOptions.length;
							if (isCustomOption) {
								optionIndex = num - 1;
								editMode = true;
								refresh();
							} else {
								done({ answer: displayOptions[num - 1], wasCustom: false });
							}
							return;
						}

						if (matchesKey(data, Key.escape)) {
							done(null);
						}
					}

					function render(width: number): string[] {
						if (cachedLines) return cachedLines;

						const lines: string[] = [];
						const add = (s: string) => lines.push(truncateToWidth(s, width));

						add(theme.fg("accent", "─".repeat(width)));
						for (const qLine of wrapText(params.question, width - 2)) {
							add(theme.fg("text", ` ${qLine}`));
						}
						lines.push("");

						for (let i = 0; i < displayOptions.length; i++) {
							const selected = i === optionIndex;
							const isCustom = allowCustom && i === displayOptions.length - 1;
							const prefix = selected ? theme.fg("accent", "> ") : "  ";
							const label = `${i + 1}. ${displayOptions[i]}`;

							if (isCustom && editMode) {
								// Show the editor inline right where the option label was
								const numPrefix = theme.fg("accent", `${i + 1}. `);
								const editorLines = editor.render(width - 6);
								add(prefix + numPrefix + (editorLines[0] ?? ""));
								// If multi-line, indent continuation lines to align
								for (let j = 1; j < editorLines.length; j++) {
									add(`      ${editorLines[j]}`);
								}
							} else if (selected) {
								add(prefix + theme.fg("accent", label));
							} else {
								add(`  ${theme.fg("text", label)}`);
							}
						}

						lines.push("");
						if (editMode) {
							add(theme.fg("dim", " Enter to submit • Esc to go back"));
						} else {
							add(
								theme.fg(
									"dim",
									" ↑↓ navigate • 1-9 quick select • Enter to select • Esc to cancel",
								),
							);
						}
						add(theme.fg("accent", "─".repeat(width)));

						cachedLines = lines;
						return lines;
					}

					return {
						render,
						invalidate: () => {
							cachedLines = undefined;
						},
						handleInput,
					};
				},
			);

			if (!result) {
				return {
					content: [{ type: "text", text: "User cancelled the selection." }],
					details: {
						question: params.question,
						options: params.options ?? null,
						allowCustomAnswer: allowCustom,
						multiSelect: false,
						answer: null,
						selectedOptions: null,
						wasCustom: false,
					} as AskDetails,
				};
			}

			const prefix = result.wasCustom ? "User wrote" : "User selected";
			return {
				content: [{ type: "text", text: `${prefix}: ${result.answer}` }],
				details: {
					question: params.question,
					options: params.options ?? null,
					allowCustomAnswer: allowCustom,
					multiSelect: false,
					answer: result.answer,
					selectedOptions: null,
					wasCustom: result.wasCustom,
				} as AskDetails,
			};
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("ask_user_question "));
			text += theme.fg("muted", args.question ?? "");
			const opts = Array.isArray(args.options) ? args.options : [];
			if (opts.length) {
				const numbered = opts.map((o: string, i: number) => `${i + 1}. ${o}`);
				const mode = args.multiSelect ? "multi-select" : "select";
				text += `\n${theme.fg("dim", `  Options (${mode}): ${numbered.join(", ")}`)}`;
			} else {
				text += `\n${theme.fg("dim", "  (free-text input)")}`;
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as AskDetails | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			if (details.answer === null) {
				return new Text(theme.fg("warning", "⊘ Cancelled"), 0, 0);
			}

			// Multi-select: show count and items
			if (details.multiSelect && details.selectedOptions) {
				const count = details.selectedOptions.length;
				const label = count === 1 ? "1 selected" : `${count} selected`;
				return new Text(
					theme.fg("success", "✓ ") +
						theme.fg("muted", `(${label}) `) +
						theme.fg("accent", details.selectedOptions.join(", ")),
					0,
					0,
				);
			}

			if (details.wasCustom) {
				return new Text(
					theme.fg("success", "✓ ") + theme.fg("muted", "(wrote) ") + theme.fg("accent", details.answer),
					0,
					0,
				);
			}

			return new Text(theme.fg("success", "✓ ") + theme.fg("accent", details.answer), 0, 0);
		},
	});
}
