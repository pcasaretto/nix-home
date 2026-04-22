---
title: "feat: Matrix rain streaming animation extension for pi"
type: feat
status: active
date: 2026-03-03
origin: docs/brainstorms/2026-03-03-matrix-rain-extension-brainstorm.md
---

# Matrix Rain Streaming Animation Extension

A pi extension that displays falling-character animation using real streamed tokens during AI response generation.

## Overview

When the AI streams a response, the actual characters being generated cascade down the terminal in Matrix-style falling columns — displayed as animated widget strips above and below the editor. The effect is theme-aware, subtle, and purely decorative.

## Design Revision: Widgets Instead of Overlays

The brainstorm proposed **two side overlays** (left-center, right-center). During planning, a critical constraint was discovered: **`ctx.ui.custom({ overlay: true })` captures keyboard focus**. Since the user may want to type during streaming (to steer or abort), modal overlays would block that input.

**Revised approach:** Use `ctx.ui.setWidget()` for animated strips above and below the editor. Widgets are persistent, non-modal UI elements that never capture focus. The visual changes from "left/right frame" to "top/bottom frame" but preserves all other decisions from the brainstorm (see brainstorm: `docs/brainstorms/2026-03-03-matrix-rain-extension-brainstorm.md`).

> **Alternative (noted for future):** If pi adds non-modal overlay support (overlays that don't capture focus), the extension could be upgraded to the original left/right frame design.

## Technical Approach

### Architecture

```
~/.pi/agent/extensions/matrix-rain.ts   (single file, no dependencies)

State:
  charQueue: string[]          — buffer of characters from streamed tokens
  columns: MatrixColumn[]      — falling column state (position, speed, trail)
  animationTimer: NodeJS timer  — setInterval handle for render loop
  isStreaming: boolean          — tracks whether animation is active
  tui: TUI reference           — captured from widget factory for requestRender()

Events → State transitions:
  session_start      → create widgets (hidden initially), capture tui reference
  message_start      → if assistant: set isStreaming=true, start animation timer
  message_update     → if assistant: split token chars into charQueue
  message_end        → if assistant: set isStreaming=false, stop timer, clear widgets
  agent_end          → fallback stop (in case message_end doesn't fire)
  session_shutdown   → cleanup timer
```

### Widget Animation Loop

```typescript
// Widget factory captures tui for requestRender()
ctx.ui.setWidget("matrix-top", (tui, theme) => {
  tuiRef = tui;  // capture for animation loop
  return {
    render: () => renderRainStrip(topColumns, theme),
    invalidate: () => {},
  };
});

// Animation: setInterval at ~75ms, same pattern as snake.ts
animationTimer = setInterval(() => {
  advanceColumns();        // move heads down, fade trails
  consumeFromQueue();      // pull chars from charQueue into column heads
  tuiRef.requestRender();  // trigger TUI re-render
}, 75);
```

### Character Flow

```
LLM token "Hello" → message_update event
  → split: ['H', 'e', 'l', 'l', 'o']
  → push to charQueue
  → animation tick consumes from queue
  → column[0] head = 'H', column[1] head = 'e', ...
  → characters fall downward, trail fades (accent → dim → very dim)
```

### Column Behavior

Each `MatrixColumn` tracks:
- `headY`: current vertical position (0 = top, wraps at height)
- `speed`: ticks between advances (randomized 1-3 for organic feel)
- `trail`: array of { char, brightness } pairs behind the head
- `trailLength`: randomized 3-8 characters

When `charQueue` is empty, columns **slow down** (increase tick delay) rather than stopping abruptly. When queue refills, columns resume normal speed.

### Color / Theming

Uses ANSI dim modifiers on the theme's accent color:
- **Head character**: `theme.fg("accent", char)` — full brightness
- **Trail position 1-2**: `\x1b[2m` (dim) + `theme.fg("accent", char)` — medium
- **Trail position 3+**: `theme.fg("dim", char)` — very faded

This adapts automatically to any pi theme (dark, light, custom).

### Responsive Behavior

- **Narrow terminals (< 80 cols):** Reduce number of columns or disable entirely
- **Terminal resize:** Widget re-renders automatically on next `requestRender()` — the `render(width)` callback receives the current width
- **Very short responses:** Few characters = few columns light up briefly, most stay dark. This is fine — the effect scales naturally with token volume

### Edge Cases & Safety

| Scenario | Handling |
|----------|----------|
| `message_end` never fires (network error) | `agent_end` as fallback stop; also a 30-second inactivity timeout (no `message_update` for 30s → auto-stop) |
| User abort (Escape/Ctrl+C) | `agent_end` fires → stops animation. Widgets don't block input, so abort works normally |
| Rapid assistant→tool→assistant cycles | Track streaming state via `isStreaming` flag. `message_start`(assistant) starts, `message_end`(assistant) stops. Tool messages are filtered by role check |
| Session switch/fork during animation | `session_start` re-initializes state. Old timer is orphaned but `session_shutdown` of old session cleans it up |
| `message_update` bursts (many tokens at once) | Characters queue up in `charQueue`, consumed gradually by animation tick. Queue acts as natural buffer |
| Zero-width characters / emoji | Use `visibleWidth()` from `@mariozechner/pi-tui` to handle display width correctly |

## Acceptance Criteria

- [ ] Extension file at `~/.pi/agent/extensions/matrix-rain.ts` loads without errors
- [ ] Animated character strips appear above and below editor when AI streams a response
- [ ] Falling characters are the actual streamed tokens (not random/fake)
- [ ] Animation uses theme accent color (not hardcoded green)
- [ ] Animation stops when streaming ends (or on error/abort)
- [ ] Editor input is never blocked (widgets, not overlays)
- [ ] No timer leaks — animation cleans up on stop/session-end/shutdown
- [ ] Graceful on narrow terminals (< 80 cols)

## MVP

### `~/.pi/agent/extensions/matrix-rain.ts`

```typescript
import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { visibleWidth, truncateToWidth } from "@mariozechner/pi-tui";

interface MatrixColumn {
  headY: number;
  speed: number;       // ticks between advances
  tickCounter: number;
  trail: { char: string; age: number }[];
  trailLength: number;
}

// Shared state
let charQueue: string[] = [];
let topColumns: MatrixColumn[] = [];
let bottomColumns: MatrixColumn[] = [];
let animationTimer: ReturnType<typeof setInterval> | null = null;
let isStreaming = false;
let tuiRef: { requestRender: () => void } | null = null;
let lastUpdateTime = 0;
let currentTheme: Theme | null = null;

const TICK_MS = 75;
const STRIP_HEIGHT = 3;         // lines per widget strip
const INACTIVITY_TIMEOUT = 30000;

function createColumns(count: number): MatrixColumn[] {
  return Array.from({ length: count }, () => ({
    headY: -Math.floor(Math.random() * STRIP_HEIGHT * 2), // staggered start
    speed: 1 + Math.floor(Math.random() * 3),
    tickCounter: 0,
    trail: [],
    trailLength: 3 + Math.floor(Math.random() * 6),
  }));
}

function advanceColumns(columns: MatrixColumn[]) {
  for (const col of columns) {
    col.tickCounter++;
    const effectiveSpeed = charQueue.length === 0 ? col.speed * 3 : col.speed;
    if (col.tickCounter < effectiveSpeed) continue;
    col.tickCounter = 0;

    // Age existing trail
    for (const t of col.trail) t.age++;
    col.trail = col.trail.filter((t) => t.age < col.trailLength);

    // Advance head
    col.headY++;
    if (col.headY >= STRIP_HEIGHT) {
      col.headY = -Math.floor(Math.random() * STRIP_HEIGHT);
      col.trail = [];
    }

    // Consume a character from the queue
    if (col.headY >= 0 && col.headY < STRIP_HEIGHT) {
      const char = charQueue.shift() || " ";
      col.trail.unshift({ char, age: 0 });
    }
  }
}

function renderStrip(columns: MatrixColumn[], theme: Theme, width: number): string[] {
  const numCols = Math.min(columns.length, width);
  const lines: string[] = [];

  for (let y = 0; y < STRIP_HEIGHT; y++) {
    let line = "";
    for (let x = 0; x < numCols; x++) {
      const col = columns[x];
      // Find if this cell has a character
      const trailEntry = col.trail.find(
        (t) => col.headY - t.age === y
      );
      if (trailEntry) {
        if (trailEntry.age === 0) {
          line += theme.fg("accent", trailEntry.char);
        } else if (trailEntry.age <= 2) {
          line += `\x1b[2m${theme.fg("accent", trailEntry.char)}\x1b[22m`;
        } else {
          line += theme.fg("dim", trailEntry.char);
        }
      } else {
        line += " ";
      }
    }
    lines.push(truncateToWidth(line, width));
  }
  return lines;
}

function startAnimation() {
  if (animationTimer) return;
  animationTimer = setInterval(() => {
    advanceColumns(topColumns);
    advanceColumns(bottomColumns);
    // Inactivity timeout
    if (Date.now() - lastUpdateTime > INACTIVITY_TIMEOUT) {
      stopAnimation();
      return;
    }
    tuiRef?.requestRender();
  }, TICK_MS);
}

function stopAnimation() {
  if (animationTimer) {
    clearInterval(animationTimer);
    animationTimer = null;
  }
  isStreaming = false;
  charQueue = [];
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setWidget("matrix-top", (tui, theme) => {
      tuiRef = tui;
      currentTheme = theme;
      topColumns = createColumns(120);
      return {
        render: () =>
          isStreaming ? renderStrip(topColumns, theme, 120) : [],
        invalidate: () => {},
      };
    });

    ctx.ui.setWidget(
      "matrix-bottom",
      (tui, theme) => {
        bottomColumns = createColumns(120);
        return {
          render: () =>
            isStreaming ? renderStrip(bottomColumns, theme, 120) : [],
          invalidate: () => {},
        };
      },
      { placement: "belowEditor" },
    );
  });

  pi.on("message_start", async (event, _ctx) => {
    if (event.message.role !== "assistant") return;
    isStreaming = true;
    lastUpdateTime = Date.now();
    charQueue = [];
    startAnimation();
  });

  pi.on("message_update", async (event, _ctx) => {
    if (!isStreaming) return;
    if (event.message.role !== "assistant") return;
    // Extract text delta from the streaming event
    const delta = event.assistantMessageEvent;
    if (delta?.type === "content" && delta.content?.type === "text") {
      const chars = [...(delta.content.text || "")];
      charQueue.push(...chars);
      lastUpdateTime = Date.now();
    }
  });

  pi.on("message_end", async (event, _ctx) => {
    if (event.message.role !== "assistant") return;
    stopAnimation();
    tuiRef?.requestRender();
  });

  // Fallback: agent_end always fires
  pi.on("agent_end", async (_event, _ctx) => {
    if (isStreaming) {
      stopAnimation();
      tuiRef?.requestRender();
    }
  });

  pi.on("session_shutdown", async (_event, _ctx) => {
    stopAnimation();
  });
}
```

> **Note:** The MVP uses global mutable state for simplicity. The `message_update` event's `assistantMessageEvent` shape needs to be verified against the actual pi runtime — the field may be structured differently. The `render()` function hardcodes 120 column count but should use the `width` parameter from the widget's render call; this will need adjustment during implementation.

## Sources

- **Origin brainstorm:** [docs/brainstorms/2026-03-03-matrix-rain-extension-brainstorm.md](docs/brainstorms/2026-03-03-matrix-rain-extension-brainstorm.md) — Key decisions carried forward: real streamed tokens as characters, theme-aware accent colors, animation during streaming only. Visual changed from side overlays to top/bottom widgets due to focus constraint.
- **Pi extension docs:** `/nix/store/.../pi-monorepo/docs/extensions.md` — event lifecycle, widget API, overlay API
- **Pi TUI docs:** `/nix/store/.../pi-monorepo/docs/tui.md` — component rendering, theming, `visibleWidth`/`truncateToWidth`
- **Pattern references:** `examples/extensions/snake.ts` (animation loop), `examples/extensions/titlebar-spinner.ts` (agent_start/end hooks), `examples/extensions/widget-placement.ts` (setWidget above/below), `examples/extensions/overlay-qa-tests.ts` (overlay toggle/animation proof)
