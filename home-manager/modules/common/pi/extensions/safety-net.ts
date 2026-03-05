/**
 * Safety Net Extension for Pi
 *
 * Integrates the cc-safety-net binary to block dangerous commands.
 * This wraps the Claude Code safety net for use with Pi.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "child_process";

const SAFETY_NET_BINARY = "@safetyNetBinary@";

interface SafetyNetOutput {
  hookSpecificOutput?: {
    permissionDecision: "allow" | "deny";
    permissionDecisionReason?: string;
  };
}

async function checkCommand(command: string, cwd: string): Promise<{ blocked: boolean; reason?: string }> {
  return new Promise((resolve) => {
    const input = JSON.stringify({
      tool_name: "Bash",
      tool_input: { command },
      cwd,
    });

    const proc = spawn(SAFETY_NET_BINARY, ["--claude-code"], {
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    proc.on("close", (code) => {
      // cc-safety-net returns empty stdout for allowed commands
      const trimmed = stdout.trim();
      if (!trimmed) {
        resolve({ blocked: false });
        return;
      }

      try {
        const result: SafetyNetOutput = JSON.parse(trimmed);
        if (result.hookSpecificOutput?.permissionDecision === "deny") {
          resolve({
            blocked: true,
            reason: result.hookSpecificOutput.permissionDecisionReason || "Blocked by safety net",
          });
        } else {
          resolve({ blocked: false });
        }
      } catch (e) {
        // If we can't parse the output, allow the command (fail-open)
        console.error("Safety net parse error:", e, stdout, stderr);
        resolve({ blocked: false });
      }
    });

    proc.on("error", (err) => {
      // Binary not found or other error - fail-open
      console.error("Safety net error:", err);
      resolve({ blocked: false });
    });

    proc.stdin.write(input);
    proc.stdin.end();
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return undefined;

    const command = event.input.command as string;
    const cwd = process.cwd();

    const result = await checkCommand(command, cwd);

    if (result.blocked) {
      return { block: true, reason: result.reason };
    }

    return undefined;
  });
}
