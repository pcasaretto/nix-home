/**
 * Subagent Tool - Delegate tasks to isolated pi subprocesses
 *
 * No agent definitions or discovery. The main agent decides the prompt,
 * model, and tools for each subagent invocation directly.
 *
 * Modes:
 *   - Single: { task, systemPrompt?, model?, tools? }
 *   - Parallel: { tasks: [...] }  (max 8 tasks, 4 concurrent)
 *   - Chain: { chain: [...] }     (sequential, {previous} placeholder)
 */

import { spawn } from "node:child_process";
import * as os from "node:os";
import * as fs from "node:fs";
import * as path from "node:path";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const MAX_PARALLEL = 8;
const MAX_CONCURRENCY = 4;
const COLLAPSED_ITEMS = 10;

// --- Helpers ---

function formatTokens(n: number): string {
	if (n < 1000) return String(n);
	if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1000000) return `${Math.round(n / 1000)}k`;
	return `${(n / 1000000).toFixed(1)}M`;
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

function emptyUsage(): UsageStats {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 };
}

function sumUsage(results: TaskResult[]): UsageStats {
	const total = emptyUsage();
	for (const r of results) {
		total.input += r.usage.input;
		total.output += r.usage.output;
		total.cacheRead += r.usage.cacheRead;
		total.cacheWrite += r.usage.cacheWrite;
		total.cost += r.usage.cost;
		total.turns += r.usage.turns;
	}
	return total;
}

function formatUsage(u: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (u.turns) parts.push(`${u.turns} turn${u.turns > 1 ? "s" : ""}`);
	if (u.input) parts.push(`↑${formatTokens(u.input)}`);
	if (u.output) parts.push(`↓${formatTokens(u.output)}`);
	if (u.cacheRead) parts.push(`R${formatTokens(u.cacheRead)}`);
	if (u.cacheWrite) parts.push(`W${formatTokens(u.cacheWrite)}`);
	if (u.cost) parts.push(`$${u.cost.toFixed(4)}`);
	if (u.contextTokens > 0) parts.push(`ctx:${formatTokens(u.contextTokens)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

function shortenPath(p: string): string {
	const home = os.homedir();
	return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
}

function formatToolCall(name: string, args: Record<string, unknown>, fg: (c: any, t: string) => string): string {
	switch (name) {
		case "bash": {
			const cmd = (args.command as string) || "...";
			return fg("muted", "$ ") + fg("toolOutput", cmd.length > 60 ? cmd.slice(0, 60) + "..." : cmd);
		}
		case "read": {
			const p = shortenPath((args.file_path || args.path || "...") as string);
			const off = args.offset as number | undefined;
			const lim = args.limit as number | undefined;
			let t = fg("accent", p);
			if (off !== undefined || lim !== undefined) {
				const s = off ?? 1;
				const e = lim !== undefined ? s + lim - 1 : "";
				t += fg("warning", `:${s}${e ? `-${e}` : ""}`);
			}
			return fg("muted", "read ") + t;
		}
		case "write": {
			const p = shortenPath((args.file_path || args.path || "...") as string);
			const lines = ((args.content || "") as string).split("\n").length;
			return fg("muted", "write ") + fg("accent", p) + (lines > 1 ? fg("dim", ` (${lines} lines)`) : "");
		}
		case "edit":
			return fg("muted", "edit ") + fg("accent", shortenPath((args.file_path || args.path || "...") as string));
		case "ls":
			return fg("muted", "ls ") + fg("accent", shortenPath((args.path || ".") as string));
		case "find":
			return fg("muted", "find ") + fg("accent", (args.pattern || "*") as string) + fg("dim", ` in ${shortenPath((args.path || ".") as string)}`);
		case "grep":
			return fg("muted", "grep ") + fg("accent", `/${args.pattern || ""}/`) + fg("dim", ` in ${shortenPath((args.path || ".") as string)}`);
		default: {
			const s = JSON.stringify(args);
			return fg("accent", name) + fg("dim", ` ${s.length > 50 ? s.slice(0, 50) + "..." : s}`);
		}
	}
}

// --- Types ---

interface TaskResult {
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
}

interface SubagentDetails {
	mode: "single" | "parallel" | "chain";
	results: TaskResult[];
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, any> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const msg of messages) {
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") items.push({ type: "text", text: part.text });
				else if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
			}
		}
	}
	return items;
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

// --- Core runner ---

type OnUpdate = (partial: AgentToolResult<SubagentDetails>) => void;

function writeTempPrompt(prompt: string): { dir: string; file: string } {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-sub-"));
	const file = path.join(dir, "prompt.md");
	fs.writeFileSync(file, prompt, { encoding: "utf-8", mode: 0o600 });
	return { dir, file };
}

async function runTask(
	cwd: string,
	task: string,
	opts: { systemPrompt?: string; model?: string; tools?: string[]; taskCwd?: string },
	step: number | undefined,
	signal: AbortSignal | undefined,
	onUpdate: OnUpdate | undefined,
	makeDetails: (results: TaskResult[]) => SubagentDetails,
): Promise<TaskResult> {
	const args: string[] = ["--mode", "json", "-p", "--no-session"];
	if (opts.model) args.push("--model", opts.model);
	if (opts.tools?.length) args.push("--tools", opts.tools.join(","));

	let tmpDir: string | null = null;
	let tmpFile: string | null = null;

	const result: TaskResult = {
		task,
		exitCode: 0,
		messages: [],
		stderr: "",
		usage: emptyUsage(),
		model: opts.model,
		step,
	};

	const emit = () => {
		onUpdate?.({
			content: [{ type: "text", text: getFinalOutput(result.messages) || "(running...)" }],
			details: makeDetails([result]),
		});
	};

	try {
		if (opts.systemPrompt?.trim()) {
			const tmp = writeTempPrompt(opts.systemPrompt);
			tmpDir = tmp.dir;
			tmpFile = tmp.file;
			args.push("--append-system-prompt", tmpFile);
		}

		args.push(`Task: ${task}`);
		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const proc = spawn("pi", args, {
				cwd: opts.taskCwd ?? cwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});

			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try { event = JSON.parse(line); } catch { return; }

				if (event.type === "message_end" && event.message) {
					const msg = event.message as Message;
					result.messages.push(msg);

					if (msg.role === "assistant") {
						result.usage.turns++;
						const u = msg.usage;
						if (u) {
							result.usage.input += u.input || 0;
							result.usage.output += u.output || 0;
							result.usage.cacheRead += u.cacheRead || 0;
							result.usage.cacheWrite += u.cacheWrite || 0;
							result.usage.cost += u.cost?.total || 0;
							result.usage.contextTokens = u.totalTokens || 0;
						}
						if (!result.model && msg.model) result.model = msg.model;
						if (msg.stopReason) result.stopReason = msg.stopReason;
						if (msg.errorMessage) result.errorMessage = msg.errorMessage;
					}
					emit();
				}

				if (event.type === "tool_result_end" && event.message) {
					result.messages.push(event.message as Message);
					emit();
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => { result.stderr += data.toString(); });

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", () => resolve(1));

			if (signal) {
				const kill = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => { if (!proc.killed) proc.kill("SIGKILL"); }, 5000);
				};
				if (signal.aborted) kill();
				else signal.addEventListener("abort", kill, { once: true });
			}
		});

		result.exitCode = exitCode;
		if (wasAborted) throw new Error("Subagent aborted");
		return result;
	} finally {
		if (tmpFile) try { fs.unlinkSync(tmpFile); } catch {}
		if (tmpDir) try { fs.rmdirSync(tmpDir); } catch {}
	}
}

async function mapConcurrent<T, R>(items: T[], limit: number, fn: (item: T, i: number) => Promise<R>): Promise<R[]> {
	const results: R[] = new Array(items.length);
	let next = 0;
	const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
		while (true) {
			const i = next++;
			if (i >= items.length) return;
			results[i] = await fn(items[i], i);
		}
	});
	await Promise.all(workers);
	return results;
}

// --- Schema ---

const TaskDef = Type.Object({
	task: Type.String({ description: "Task description for the subagent" }),
	systemPrompt: Type.Optional(Type.String({ description: "System prompt override for this task" })),
	model: Type.Optional(Type.String({ description: "Model to use (e.g. claude-haiku-4-5)" })),
	tools: Type.Optional(Type.Array(Type.String(), { description: "Tools to enable (e.g. [\"read\", \"grep\", \"ls\"])" })),
	cwd: Type.Optional(Type.String({ description: "Working directory for the subagent" })),
});

const ChainStep = Type.Object({
	task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
	systemPrompt: Type.Optional(Type.String({ description: "System prompt override for this step" })),
	model: Type.Optional(Type.String({ description: "Model to use for this step" })),
	tools: Type.Optional(Type.Array(Type.String(), { description: "Tools to enable for this step" })),
	cwd: Type.Optional(Type.String({ description: "Working directory for this step" })),
});

const SubagentParams = Type.Object({
	// Single mode
	task: Type.Optional(Type.String({ description: "Task to delegate (single mode)" })),
	systemPrompt: Type.Optional(Type.String({ description: "System prompt for the subagent" })),
	model: Type.Optional(Type.String({ description: "Model to use (e.g. claude-haiku-4-5)" })),
	tools: Type.Optional(Type.Array(Type.String(), { description: "Tools to enable" })),
	cwd: Type.Optional(Type.String({ description: "Working directory (single mode)" })),
	// Parallel mode
	tasks: Type.Optional(Type.Array(TaskDef, { description: "Array of tasks for parallel execution (max 8)" })),
	// Chain mode
	chain: Type.Optional(Type.Array(ChainStep, { description: "Sequential steps; use {previous} for prior output" })),
});

// --- Extension ---

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate tasks to isolated pi subprocesses with their own context windows.",
			"You decide the prompt, model, and tools — no agent definitions needed.",
			"Modes: single (task), parallel (tasks array), chain (sequential with {previous}).",
			"Use for reconnaissance, parallel search, multi-step workflows, or any task that benefits from a fresh context.",
		].join(" "),
		promptGuidelines: [
			"Subagents preserve your rich main context by offloading work to disposable workers with fresh context windows.",
			"You are the context hub — you accumulate deep understanding, then distill exactly the right information into each subagent's task.",
			"Write detailed, prescriptive task descriptions. Prime each subagent with just the context it needs from your accumulated knowledge.",
			"Subagent results enrich your main context. Use their output to deepen your understanding before dispatching more work.",
			"For fast recon, use a smaller model (e.g. claude-haiku-4-5) with read-only tools (read, grep, find, ls).",
			"For implementation tasks, use the default model with all tools.",
			"In chain mode, use {previous} in the task to inject the prior step's output.",
			"Parallel mode is great for multiple review angles (e.g. general, security, performance) or querying multiple sources.",
			"You usually don't need systemPrompt — a detailed task description is sufficient.",
		],
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const hasChain = (params.chain?.length ?? 0) > 0;
			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.task);
			const modeCount = Number(hasChain) + Number(hasTasks) + Number(hasSingle);

			const makeDetails = (mode: "single" | "parallel" | "chain") =>
				(results: TaskResult[]): SubagentDetails => ({ mode, results });

			if (modeCount !== 1) {
				return {
					content: [{ type: "text", text: "Provide exactly one of: task (single), tasks (parallel), or chain." }],
					details: makeDetails("single")([]),
				};
			}

			// --- Single ---
			if (params.task) {
				const result = await runTask(
					ctx.cwd,
					params.task,
					{ systemPrompt: params.systemPrompt, model: params.model, tools: params.tools, taskCwd: params.cwd },
					undefined,
					signal,
					onUpdate,
					makeDetails("single"),
				);
				const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
				if (isError) {
					const msg = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
					return {
						content: [{ type: "text", text: `Subagent ${result.stopReason || "failed"}: ${msg}` }],
						details: makeDetails("single")([result]),
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
					details: makeDetails("single")([result]),
				};
			}

			// --- Chain ---
			if (params.chain && params.chain.length > 0) {
				const results: TaskResult[] = [];
				let previousOutput = "";

				for (let i = 0; i < params.chain.length; i++) {
					const step = params.chain[i];
					const taskText = step.task.replace(/\{previous\}/g, previousOutput);

					const chainUpdate: OnUpdate | undefined = onUpdate
						? (partial) => {
								const cur = partial.details?.results[0];
								if (cur) onUpdate({ content: partial.content, details: makeDetails("chain")([...results, cur]) });
							}
						: undefined;

					const result = await runTask(
						ctx.cwd,
						taskText,
						{ systemPrompt: step.systemPrompt, model: step.model, tools: step.tools, taskCwd: step.cwd },
						i + 1,
						signal,
						chainUpdate,
						makeDetails("chain"),
					);
					results.push(result);

					const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
					if (isError) {
						const msg = result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
						return {
							content: [{ type: "text", text: `Chain stopped at step ${i + 1}: ${msg}` }],
							details: makeDetails("chain")(results),
							isError: true,
						};
					}
					previousOutput = getFinalOutput(result.messages);
				}

				return {
					content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
					details: makeDetails("chain")(results),
				};
			}

			// --- Parallel ---
			if (params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > MAX_PARALLEL) {
					return {
						content: [{ type: "text", text: `Too many tasks (${params.tasks.length}). Max is ${MAX_PARALLEL}.` }],
						details: makeDetails("parallel")([]),
					};
				}

				const allResults: TaskResult[] = params.tasks.map((t) => ({
					task: t.task,
					exitCode: -1, // running
					messages: [],
					stderr: "",
					usage: emptyUsage(),
					model: t.model,
				}));

				const emitParallel = () => {
					if (!onUpdate) return;
					const done = allResults.filter((r) => r.exitCode !== -1).length;
					const running = allResults.length - done;
					onUpdate({
						content: [{ type: "text", text: `Parallel: ${done}/${allResults.length} done, ${running} running...` }],
						details: makeDetails("parallel")([...allResults]),
					});
				};

				const results = await mapConcurrent(params.tasks, MAX_CONCURRENCY, async (t, idx) => {
					const result = await runTask(
						ctx.cwd,
						t.task,
						{ systemPrompt: t.systemPrompt, model: t.model, tools: t.tools, taskCwd: t.cwd },
						undefined,
						signal,
						(partial) => {
							if (partial.details?.results[0]) {
								allResults[idx] = partial.details.results[0];
								emitParallel();
							}
						},
						makeDetails("parallel"),
					);
					allResults[idx] = result;
					emitParallel();
					return result;
				});

				const ok = results.filter((r) => r.exitCode === 0).length;
				const summaries = results.map((r) => {
					const out = getFinalOutput(r.messages);
					const preview = out.slice(0, 100) + (out.length > 100 ? "..." : "");
					return `[task] ${r.exitCode === 0 ? "done" : "failed"}: ${preview || "(no output)"}`;
				});

				return {
					content: [{ type: "text", text: `Parallel: ${ok}/${results.length} succeeded\n\n${summaries.join("\n\n")}` }],
					details: makeDetails("parallel")(results),
				};
			}

			return {
				content: [{ type: "text", text: "No task specified." }],
				details: makeDetails("single")([]),
			};
		},

		// --- Rendering ---

		renderCall(args, theme) {
			const t = (c: any, s: string) => theme.fg(c, s);
			const title = t("toolTitle", theme.bold("subagent "));

			if (args.chain?.length) {
				let text = title + t("accent", `chain (${args.chain.length} steps)`);
				for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
					const s = args.chain[i];
					const clean = s.task.replace(/\{previous\}/g, "").trim();
					const preview = clean.length > 50 ? clean.slice(0, 50) + "..." : clean;
					text += `\n  ${t("muted", `${i + 1}.`)} ${t("dim", preview)}`;
					if (s.model) text += ` ${t("muted", `[${s.model}]`)}`;
				}
				if (args.chain.length > 3) text += `\n  ${t("muted", `... +${args.chain.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}

			if (args.tasks?.length) {
				let text = title + t("accent", `parallel (${args.tasks.length} tasks)`);
				for (const task of args.tasks.slice(0, 3)) {
					const preview = task.task.length > 50 ? task.task.slice(0, 50) + "..." : task.task;
					text += `\n  ${t("dim", preview)}`;
					if (task.model) text += ` ${t("muted", `[${task.model}]`)}`;
				}
				if (args.tasks.length > 3) text += `\n  ${t("muted", `... +${args.tasks.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}

			const preview = args.task ? (args.task.length > 60 ? args.task.slice(0, 60) + "..." : args.task) : "...";
			let text = title + t("dim", preview);
			if (args.model) text += ` ${t("muted", `[${args.model}]`)}`;
			if (args.tools?.length) text += ` ${t("muted", `tools: ${args.tools.join(", ")}`)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const fg = theme.fg.bind(theme);
			const mdTheme = getMarkdownTheme();

			const renderItems = (items: DisplayItem[], limit?: number) => {
				const show = limit ? items.slice(-limit) : items;
				const skipped = limit && items.length > limit ? items.length - limit : 0;
				let text = "";
				if (skipped > 0) text += fg("muted", `... ${skipped} earlier items\n`);
				for (const item of show) {
					if (item.type === "text") {
						const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
						text += `${fg("toolOutput", preview)}\n`;
					} else {
						text += `${fg("muted", "→ ") + formatToolCall(item.name, item.args, fg)}\n`;
					}
				}
				return text.trimEnd();
			};

			// --- Single ---
			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isErr = r.exitCode !== 0 || r.stopReason === "error" || r.stopReason === "aborted";
				const icon = isErr ? fg("error", "✗") : fg("success", "✓");
				const items = getDisplayItems(r.messages);
				const output = getFinalOutput(r.messages);

				if (expanded) {
					const c = new Container();
					let header = `${icon} ${fg("toolTitle", theme.bold("subagent"))}`;
					if (r.model) header += ` ${fg("muted", `[${r.model}]`)}`;
					if (isErr && r.stopReason) header += ` ${fg("error", `[${r.stopReason}]`)}`;
					c.addChild(new Text(header, 0, 0));
					if (isErr && r.errorMessage) c.addChild(new Text(fg("error", `Error: ${r.errorMessage}`), 0, 0));
					c.addChild(new Spacer(1));
					c.addChild(new Text(fg("muted", "─── Task ───"), 0, 0));
					c.addChild(new Text(fg("dim", r.task), 0, 0));
					c.addChild(new Spacer(1));
					c.addChild(new Text(fg("muted", "─── Output ───"), 0, 0));
					for (const item of items) {
						if (item.type === "toolCall")
							c.addChild(new Text(fg("muted", "→ ") + formatToolCall(item.name, item.args, fg), 0, 0));
					}
					if (output) {
						c.addChild(new Spacer(1));
						c.addChild(new Markdown(output.trim(), 0, 0, mdTheme));
					} else if (items.length === 0) {
						c.addChild(new Text(fg("muted", "(no output)"), 0, 0));
					}
					const u = formatUsage(r.usage, r.model);
					if (u) { c.addChild(new Spacer(1)); c.addChild(new Text(fg("dim", u), 0, 0)); }
					return c;
				}

				let text = `${icon} ${fg("toolTitle", theme.bold("subagent"))}`;
				if (r.model) text += ` ${fg("muted", `[${r.model}]`)}`;
				if (isErr && r.errorMessage) text += `\n${fg("error", `Error: ${r.errorMessage}`)}`;
				else if (items.length === 0) text += `\n${fg("muted", "(no output)")}`;
				else text += `\n${renderItems(items, COLLAPSED_ITEMS)}`;
				const u = formatUsage(r.usage, r.model);
				if (u) text += `\n${fg("dim", u)}`;
				return new Text(text, 0, 0);
			}

			// --- Chain ---
			if (details.mode === "chain") {
				const ok = details.results.filter((r) => r.exitCode === 0).length;
				const icon = ok === details.results.length ? fg("success", "✓") : fg("error", "✗");

				if (expanded) {
					const c = new Container();
					c.addChild(new Text(`${icon} ${fg("toolTitle", theme.bold("chain "))}${fg("accent", `${ok}/${details.results.length} steps`)}`, 0, 0));
					for (const r of details.results) {
						const ri = r.exitCode === 0 ? fg("success", "✓") : fg("error", "✗");
						const output = getFinalOutput(r.messages);
						c.addChild(new Spacer(1));
						c.addChild(new Text(`${fg("muted", `─── Step ${r.step} `)}${ri}${r.model ? ` ${fg("muted", `[${r.model}]`)}` : ""}`, 0, 0));
						c.addChild(new Text(fg("muted", "Task: ") + fg("dim", r.task), 0, 0));
						for (const item of getDisplayItems(r.messages)) {
							if (item.type === "toolCall")
								c.addChild(new Text(fg("muted", "→ ") + formatToolCall(item.name, item.args, fg), 0, 0));
						}
						if (output) { c.addChild(new Spacer(1)); c.addChild(new Markdown(output.trim(), 0, 0, mdTheme)); }
						const su = formatUsage(r.usage, r.model);
						if (su) c.addChild(new Text(fg("dim", su), 0, 0));
					}
					const tu = formatUsage(sumUsage(details.results));
					if (tu) { c.addChild(new Spacer(1)); c.addChild(new Text(fg("dim", `Total: ${tu}`), 0, 0)); }
					return c;
				}

				let text = `${icon} ${fg("toolTitle", theme.bold("chain "))}${fg("accent", `${ok}/${details.results.length} steps`)}`;
				for (const r of details.results) {
					const ri = r.exitCode === 0 ? fg("success", "✓") : fg("error", "✗");
					const items = getDisplayItems(r.messages);
					text += `\n\n${fg("muted", `─── Step ${r.step} `)}${ri}`;
					text += items.length === 0 ? `\n${fg("muted", "(no output)")}` : `\n${renderItems(items, 5)}`;
				}
				const tu = formatUsage(sumUsage(details.results));
				if (tu) text += `\n\n${fg("dim", `Total: ${tu}`)}`;
				return new Text(text, 0, 0);
			}

			// --- Parallel ---
			if (details.mode === "parallel") {
				const running = details.results.filter((r) => r.exitCode === -1).length;
				const ok = details.results.filter((r) => r.exitCode === 0).length;
				const fail = details.results.filter((r) => r.exitCode > 0).length;
				const isRunning = running > 0;
				const icon = isRunning ? fg("warning", "⏳") : fail > 0 ? fg("warning", "◐") : fg("success", "✓");
				const status = isRunning
					? `${ok + fail}/${details.results.length} done, ${running} running`
					: `${ok}/${details.results.length} tasks`;

				if (expanded && !isRunning) {
					const c = new Container();
					c.addChild(new Text(`${icon} ${fg("toolTitle", theme.bold("parallel "))}${fg("accent", status)}`, 0, 0));
					for (const r of details.results) {
						const ri = r.exitCode === 0 ? fg("success", "✓") : fg("error", "✗");
						const output = getFinalOutput(r.messages);
						c.addChild(new Spacer(1));
						c.addChild(new Text(`${fg("muted", "─── ")}${ri}${r.model ? ` ${fg("muted", `[${r.model}]`)}` : ""}`, 0, 0));
						c.addChild(new Text(fg("muted", "Task: ") + fg("dim", r.task), 0, 0));
						for (const item of getDisplayItems(r.messages)) {
							if (item.type === "toolCall")
								c.addChild(new Text(fg("muted", "→ ") + formatToolCall(item.name, item.args, fg), 0, 0));
						}
						if (output) { c.addChild(new Spacer(1)); c.addChild(new Markdown(output.trim(), 0, 0, mdTheme)); }
						const su = formatUsage(r.usage, r.model);
						if (su) c.addChild(new Text(fg("dim", su), 0, 0));
					}
					const tu = formatUsage(sumUsage(details.results));
					if (tu) { c.addChild(new Spacer(1)); c.addChild(new Text(fg("dim", `Total: ${tu}`), 0, 0)); }
					return c;
				}

				let text = `${icon} ${fg("toolTitle", theme.bold("parallel "))}${fg("accent", status)}`;
				for (const r of details.results) {
					const ri = r.exitCode === -1 ? fg("warning", "⏳") : r.exitCode === 0 ? fg("success", "✓") : fg("error", "✗");
					const items = getDisplayItems(r.messages);
					text += `\n\n${fg("muted", "─── ")}${ri}`;
					text += items.length === 0
						? `\n${fg("muted", r.exitCode === -1 ? "(running...)" : "(no output)")}`
						: `\n${renderItems(items, 5)}`;
				}
				if (!isRunning) {
					const tu = formatUsage(sumUsage(details.results));
					if (tu) text += `\n\n${fg("dim", `Total: ${tu}`)}`;
				}
				return new Text(text, 0, 0);
			}

			const text = result.content[0];
			return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
		},
	});
}
