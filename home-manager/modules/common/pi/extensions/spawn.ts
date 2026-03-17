/**
 * Spawn tool - async fire-and-forget pi subagent
 *
 * Spawns a pi subprocess in the background and returns immediately.
 * Results are delivered via pi.sendMessage({ triggerTurn: true }) when the task completes.
 *
 * Call spawn multiple times for concurrent execution — each runs independently.
 * For sequential work: spawn task 1, wait for its result message, then spawn task 2.
 */

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const RESULTS_DIR = path.join(os.tmpdir(), "pi-spawn-results");
// Prefix task IDs with our PID so subprocesses (which also load this extension)
// don't pick up and re-deliver .done files that belong to the parent session.
const TASK_PREFIX = `${process.pid}-`;

// --- Types ---

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	turns: number;
}

interface TaskInfo {
	id: string;
	task: string;
	pid?: number;
	status: "running" | "done" | "failed";
	startTime: number;
	endTime?: number;
	model?: string;
	output?: string;
	usage?: UsageStats;
	exitCode?: number;
}

// --- Helpers ---

function shellEscape(s: string): string {
	return "'" + s.replace(/'/g, "'\\''") + "'";
}

function formatDuration(ms: number): string {
	if (ms < 1000) return `${ms}ms`;
	if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
	return `${Math.floor(ms / 60000)}m${Math.floor((ms % 60000) / 1000)}s`;
}

function formatTokens(n: number): string {
	if (n < 1000) return String(n);
	if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1000000) return `${Math.round(n / 1000)}k`;
	return `${(n / 1000000).toFixed(1)}M`;
}

function formatUsage(u: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (u.turns) parts.push(`${u.turns} turn${u.turns > 1 ? "s" : ""}`);
	if (u.input) parts.push(`↑${formatTokens(u.input)}`);
	if (u.output) parts.push(`↓${formatTokens(u.output)}`);
	if (u.cacheRead) parts.push(`R${formatTokens(u.cacheRead)}`);
	if (u.cacheWrite) parts.push(`W${formatTokens(u.cacheWrite)}`);
	if (u.cost) parts.push(`$${u.cost.toFixed(4)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

function parseJsonlResult(jsonlPath: string): { output: string; usage: UsageStats; model?: string } {
	const usage: UsageStats = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
	let lastOutput = "";
	let model: string | undefined;

	let content = "";
	try {
		content = fs.readFileSync(jsonlPath, "utf-8");
	} catch {
		return { output: "(no output)", usage };
	}

	for (const line of content.split("\n")) {
		if (!line.trim()) continue;
		let event: any;
		try {
			event = JSON.parse(line);
		} catch {
			continue;
		}

		if (event.type === "message_end" && event.message?.role === "assistant") {
			const msg = event.message;
			usage.turns++;
			if (msg.usage) {
				usage.input += msg.usage.input || 0;
				usage.output += msg.usage.output || 0;
				usage.cacheRead += msg.usage.cacheRead || 0;
				usage.cacheWrite += msg.usage.cacheWrite || 0;
				usage.cost += msg.usage.cost?.total || 0;
			}
			if (msg.model && !model) model = msg.model;
			// Track the last text block from this assistant message
			for (const part of msg.content || []) {
				if (part.type === "text" && part.text) lastOutput = part.text;
			}
		}
	}

	return { output: lastOutput || "(no output)", usage, model };
}

// --- Extension ---

export default function (pi: ExtensionAPI) {
	// In-memory task registry (survives for the session lifetime)
	const tasks = new Map<string, TaskInfo>();

	// Ensure results dir exists
	fs.mkdirSync(RESULTS_DIR, { recursive: true });

	// Handle a completed task — called when .done file is detected
	function handleDone(id: string): void {
		// Ignore tasks spawned by other pi processes (e.g. our own subprocesses
		// which also load this extension and would otherwise re-deliver results).
		if (!id.startsWith(TASK_PREFIX)) return;
		const donePath = path.join(RESULTS_DIR, `${id}.done`);
		const jsonlPath = path.join(RESULTS_DIR, `${id}.jsonl`);
		const stderrPath = path.join(RESULTS_DIR, `${id}.stderr`);

		let exitCode = 0;
		try {
			exitCode = parseInt(fs.readFileSync(donePath, "utf-8").trim(), 10) || 0;
		} catch {
			return; // .done not readable yet, will retry via watch
		}

		const { output, usage, model } = parseJsonlResult(jsonlPath);
		const task = tasks.get(id);
		const now = Date.now();
		const duration = task ? now - task.startTime : 0;
		const status = exitCode === 0 ? "done" : "failed";
		const effectiveModel = model || task?.model;

		// Update in-memory task state
		if (task) {
			task.status = status;
			task.endTime = now;
			task.output = output;
			task.usage = usage;
			task.exitCode = exitCode;
			task.model = effectiveModel;
		}

		// Cleanup result files
		try { fs.unlinkSync(donePath); } catch {}
		try { fs.unlinkSync(jsonlPath); } catch {}
		try { fs.unlinkSync(stderrPath); } catch {}

		// Build content: header + full output
		const durationStr = formatDuration(duration);
		const usageStr = formatUsage(usage, effectiveModel);
		const shortId = id.slice(0, 8);
		const statusLabel = exitCode === 0 ? "completed" : `failed (exit ${exitCode})`;
		const meta = [durationStr, usageStr].filter(Boolean).join(", ");
		const header = `Background task [${shortId}] ${statusLabel}${meta ? ` — ${meta}` : ""}`;
		const content = exitCode === 0
			? `${header}:\n\n${output}`
			: `${header}:\n\n${output}`;

		pi.sendMessage(
			{
				customType: "spawn-complete",
				content,
				display: true,
				details: { taskId: id, status, exitCode, duration, usage, model: effectiveModel },
			},
			{ triggerTurn: true, deliverAs: "followUp" },
		);
	}

	// Watch for .done files from background tasks
	const watcher = fs.watch(RESULTS_DIR, (eventType, filename) => {
		if (eventType === "rename" && filename && filename.endsWith(".done")) {
			const id = filename.slice(0, -5);
			// Small delay to ensure file is fully written before reading
			setTimeout(() => {
				const donePath = path.join(RESULTS_DIR, filename);
				if (fs.existsSync(donePath)) handleDone(id);
			}, 100);
		}
	});

	// On load, pick up any .done files from before this extension started
	// (e.g. tasks that completed during an extension reload)
	try {
		for (const f of fs.readdirSync(RESULTS_DIR)) {
			if (f.endsWith(".done")) {
				const id = f.slice(0, -5);
				setTimeout(() => handleDone(id), 200);
			}
		}
	} catch {}

	// Cleanup on session shutdown
	pi.on("session_shutdown", async () => {
		watcher.close();
		// Signal any running tasks
		for (const task of tasks.values()) {
			if (task.status === "running" && task.pid) {
				try { process.kill(task.pid, "SIGTERM"); } catch {}
			}
		}
		// Remove temp result files
		try {
			for (const f of fs.readdirSync(RESULTS_DIR)) {
				try { fs.unlinkSync(path.join(RESULTS_DIR, f)); } catch {}
			}
		} catch {}
	});

	// --- Tool: spawn ---

	pi.registerTool({
		name: "spawn",
		label: "Spawn",
		description:
			"Spawn a background pi task. Returns immediately — results arrive as a followUp message when the task completes. " +
			"Call spawn multiple times to run tasks concurrently; each runs in its own independent pi process.",
		promptGuidelines: [
			"spawn is fire-and-forget — it returns immediately. Results arrive later as a followUp message that triggers a new LLM turn.",
			"Call spawn multiple times for concurrent work — each task runs independently in the background.",
			"For sequential work: spawn task 1, wait for its result message, then spawn task 2.",
			"Don't use spawn for simple tasks you can do directly with read/bash/grep — spawn has real overhead (process startup, fresh context).",
			"Good uses: long-running analysis, parallel code investigations, code reviews, builds/tests, anything that takes >30 seconds.",
			"Write fully self-contained task descriptions — the spawned agent has zero shared context with you.",
			"Use /tasks to check status of running background tasks.",
		],
		parameters: Type.Object({
			task: Type.String({ description: "Task description for the background agent" }),
			model: Type.Optional(Type.String({ description: "Model override (e.g. claude-haiku-4-5)" })),
			tools: Type.Optional(
				Type.Array(Type.String(), { description: 'Tool restrictions (e.g. ["read", "grep", "find"])' }),
			),
			systemPrompt: Type.Optional(Type.String({ description: "System prompt override" })),
			cwd: Type.Optional(Type.String({ description: "Working directory override" })),
		}),

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const id = TASK_PREFIX + randomUUID();
			const taskCwd = params.cwd ?? ctx.cwd;
			const jsonlPath = path.join(RESULTS_DIR, `${id}.jsonl`);
			const stderrPath = path.join(RESULTS_DIR, `${id}.stderr`);
			const donePath = path.join(RESULTS_DIR, `${id}.done`);

			// Write system prompt to temp file if provided (avoids shell escaping issues)
			let sysPromptPath: string | null = null;
			if (params.systemPrompt?.trim()) {
				sysPromptPath = path.join(os.tmpdir(), `pi-spawn-sys-${id}.txt`);
				fs.writeFileSync(sysPromptPath, params.systemPrompt, { mode: 0o600 });
			}

			// Build pi args
			const piArgs: string[] = ["--mode", "json", "-p", "--no-session"];
			if (params.model) piArgs.push("--model", params.model);
			if (params.tools?.length) piArgs.push("--tools", params.tools.join(","));
			if (sysPromptPath) piArgs.push("--append-system-prompt", sysPromptPath);
			piArgs.push(`Task: ${params.task}`);

			// Write a shell script to a temp file — cleanest way to handle all quoting
			const scriptPath = path.join(os.tmpdir(), `pi-spawn-${id}.sh`);
			const scriptLines = [
				"#!/bin/sh",
				`pi ${piArgs.map(shellEscape).join(" ")} \\`,
				`  > ${shellEscape(jsonlPath)} \\`,
				`  2> ${shellEscape(stderrPath)}`,
				`echo $? > ${shellEscape(donePath)}`,
				sysPromptPath ? `rm -f ${shellEscape(sysPromptPath)}` : null,
				`rm -f ${shellEscape(scriptPath)}`,
			].filter(Boolean).join("\n") + "\n";

			fs.writeFileSync(scriptPath, scriptLines, { mode: 0o700 });

			const proc = spawn("sh", [scriptPath], {
				cwd: taskCwd,
				detached: true,
				stdio: "ignore",
			});
			const pid = proc.pid;
			proc.unref();

			// Register task
			tasks.set(id, {
				id,
				task: params.task,
				pid,
				status: "running",
				startTime: Date.now(),
				model: params.model,
			});

			const shortId = id.slice(0, 8);
			return {
				content: [
					{
						type: "text",
						text: `Background task [${shortId}] started${pid ? ` (pid ${pid})` : ""}. Results will arrive as a followUp message when complete. Use /tasks to check status.`,
					},
				],
				details: { taskId: id, pid },
			};
		},

		renderCall(args, theme) {
			const fg = theme.fg.bind(theme);
			const preview = args.task
				? args.task.length > 70 ? args.task.slice(0, 70) + "..." : args.task
				: "...";
			let text = fg("toolTitle", theme.bold("spawn ")) + fg("dim", preview);
			if (args.model) text += ` ${fg("muted", `[${args.model as string}]`)}`;
			if ((args.tools as string[] | undefined)?.length)
				text += ` ${fg("muted", `tools:${(args.tools as string[]).join(",")}`)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const fg = theme.fg.bind(theme);
			const details = result.details as { taskId?: string; pid?: number } | undefined;
			const shortId = details?.taskId ? details.taskId.slice(0, 8) : "?";
			const pidStr = details?.pid ? ` pid ${details.pid}` : "";
			return new Text(
				fg("warning", "⏳") + ` ${fg("toolTitle", theme.bold("spawn "))}${fg("dim", `[${shortId}]${pidStr} running in background`)}`,
				0,
				0,
			);
		},
	});

	// --- Message renderer: spawn-complete ---

	pi.registerMessageRenderer("spawn-complete", (message, options, theme) => {
		const { expanded } = options;
		const fg = theme.fg.bind(theme);
		const details = message.details as {
			taskId?: string;
			status?: string;
			exitCode?: number;
			duration?: number;
			usage?: UsageStats;
			model?: string;
		} | undefined;

		const isSuccess = details?.status === "done";
		const icon = isSuccess ? fg("success", "✓") : fg("error", "✗");
		const shortId = details?.taskId ? details.taskId.slice(0, 8) : "?";
		const durationStr = details?.duration ? formatDuration(details.duration) : "";
		const usageStr = details?.usage ? formatUsage(details.usage, details.model) : "";

		const statusText = isSuccess ? fg("success", "completed") : fg("error", "failed");
		const meta = [durationStr, usageStr].filter(Boolean).join(" ");

		const header =
			`${icon} ${fg("toolTitle", theme.bold("spawn "))}${fg("dim", `[${shortId}]`)} ${statusText}` +
			(meta ? `  ${fg("dim", meta)}` : "");

		// Extract just the output portion (after "header:\n\n")
		const outputStart = message.content.indexOf("\n\n");
		const outputText = outputStart >= 0 ? message.content.slice(outputStart + 2) : message.content;

		if (expanded) {
			const c = new Container();
			c.addChild(new Text(header, 0, 0));
			if (outputText) {
				c.addChild(new Spacer(1));
				c.addChild(new Markdown(outputText.trim(), 0, 0, getMarkdownTheme()));
			}
			return c;
		}

		// Collapsed: header + first 3 lines of output
		const preview = outputText.split("\n").slice(0, 3).join("\n");
		let text = header;
		if (preview) text += `\n${fg("toolOutput", preview)}`;
		return new Text(text, 0, 0);
	});

	// --- Command: /tasks ---

	pi.registerCommand("tasks", {
		description: "Show running and recent background spawn tasks",
		handler: async (_args, _ctx) => {
			if (tasks.size === 0) {
				pi.sendMessage({ customType: "spawn-complete", content: "No background tasks this session.", display: true }, {});
				return;
			}

			const running = [...tasks.values()].filter((t) => t.status === "running");
			const finished = [...tasks.values()]
				.filter((t) => t.status !== "running")
				.sort((a, b) => (b.endTime ?? 0) - (a.endTime ?? 0))
				.slice(0, 10);

			const lines: string[] = [];

			if (running.length > 0) {
				lines.push(`**Running (${running.length}):**`);
				for (const t of running) {
					const elapsed = formatDuration(Date.now() - t.startTime);
					const preview = t.task.length > 60 ? t.task.slice(0, 60) + "..." : t.task;
					lines.push(`- ⏳ \`[${t.id.slice(0, 8)}]\` ${elapsed} — ${preview}`);
				}
			}

			if (finished.length > 0) {
				if (lines.length > 0) lines.push("");
				lines.push(`**Recent (${finished.length}):**`);
				for (const t of finished) {
					const icon = t.status === "done" ? "✓" : "✗";
					const duration = t.endTime ? formatDuration(t.endTime - t.startTime) : "?";
					const preview = t.task.length > 60 ? t.task.slice(0, 60) + "..." : t.task;
					lines.push(`- ${icon} \`[${t.id.slice(0, 8)}]\` ${duration} — ${preview}`);
				}
			}

			pi.sendMessage(
				{ customType: "spawn-complete", content: lines.join("\n"), display: true },
				{},
			);
		},
	});
}
