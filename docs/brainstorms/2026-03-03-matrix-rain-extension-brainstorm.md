# Matrix Rain Animation Extension for Pi

**Date:** 2026-03-03
**Status:** Brainstorm

## What We're Building

A pi extension that displays a Matrix-style falling character animation around the edges of the terminal while the AI is streaming tokens. The effect creates a "digital rain" frame — columns of cascading characters on the left and right sides of the terminal — that appears when response text starts streaming and disappears when it stops.

### Core Behavior

- **Trigger:** Animation starts on `message_start` (when `event.message.role === "assistant"`) and stops on the corresponding `message_end`
- **Visual:** Matrix-style falling character columns rendered as overlays on the left and right edges of the terminal
- **Characters:** The actual streamed tokens from the AI response, split character-by-character and fed into rain columns. The real response text cascades down the screen as it's generated.
- **Colors:** Theme-aware — uses pi's `accent` color at varying brightness levels instead of hardcoded green, so it adapts to any theme
- **Prominence:** Dim/subtle — the "head" of each falling column uses the accent color at full brightness, trailing characters fade to very dim. The effect is atmospheric, not attention-grabbing

### What It Is NOT

- Not a full-screen takeover (content stays readable in the center)
- Not interactive (no keyboard handling needed — overlays auto-dismiss)
- Not persistent (only visible during active token streaming)

## Why This Approach

**Multiple edge overlays** was chosen over alternatives because:

1. **Widget sandwich** (above/below editor) only gives horizontal strips — no side columns, less immersive
2. **Full-screen overlay** blocks content and requires input passthrough — overly complex for a decorative effect
3. **Edge overlays** use pi's `overlayOptions` anchoring (`left-center`, `right-center`) with percentage widths, keeping the center content completely untouched

The pi overlay system supports multiple simultaneous overlays, percentage-based sizing, and anchor positioning — all of which map directly to this design.

## Key Decisions

1. **Trigger on streaming only** — `message_start`/`message_end` filtered to `event.message.role === "assistant"`, not `agent_start`/`agent_end` (which includes tool execution). Note: these events fire for all message types (user, assistant, toolResult), so filtering by role is required.

2. **Theme-aware colors** — Use `theme.fg("accent", ...)` and dim ANSI modifiers rather than hardcoded Matrix green. This ensures the effect looks good regardless of the user's theme (dark, light, custom).

3. **Two side overlays** — Left strip and right strip, each 12% of terminal width. Anchored via `overlayOptions.anchor` to `left-center` and `right-center`. Each overlay is a self-contained Matrix rain component.

4. **Real streamed tokens** — Characters from the actual AI response are split individually and queued into a buffer. Rain column "heads" consume from this buffer, so the falling characters ARE the response text. When the buffer is empty (between bursts), columns pause or recycle recent characters.

5. **Animation via setInterval** — Same pattern as the snake game: `setInterval` at 75ms tick rate, calling `tui.requestRender()` each frame. Cleanup on `message_end`.

6. **Responsive** — Use `overlayOptions.visible` callback to hide on narrow terminals (e.g., < 80 columns) so the rain doesn't squeeze content.

## Technical Shape

```
Extension: ~/.pi/agent/extensions/matrix-rain.ts

Events:
  message_start → if assistant message, show overlays
  message_end   → if assistant message, hide overlays

Components:
  MatrixRainColumn — single column of falling characters
  MatrixRainPanel  — grid of columns, manages animation loop

Overlay config:
  Left:  { anchor: "left-center", width: "12%", minWidth: 8 (columns) }
  Right: { anchor: "right-center", width: "12%", minWidth: 8 (columns) }
  Created once at session_start via ctx.ui.custom() with onHandle callback
  Toggled via handle.setHidden(true/false) on message_start/message_end

Animation:
  - `message_update` events feed tokens into a shared character queue
  - Each column has a "head" position that advances downward
  - Column heads pull the next character from the queue (real response text)
  - Trail behind the head fades in brightness (accent → dim → very dim)
  - When head reaches bottom, it resets to top with random delay
  - Columns have different speeds/lengths for organic feel
  - When queue is empty, columns can pause or slow down
```

## Open Questions

_None — all key decisions resolved during brainstorming._

## Resolved Questions

1. **Where should the animation appear?** → Background/side overlay, specifically dim frame around edges with clear center
2. **When should it be visible?** → Only during active token streaming
3. **What characters?** → Actual streamed tokens, split character-by-character into rain columns
4. **How prominent?** → Dim overlay frame around edges
5. **Color palette?** → Theme-aware using pi's accent color
6. **Which approach?** → Multiple edge overlays (Approach A)
7. **How to display real tokens?** → Character-by-character split, fed into columns as head characters (closest to movie feel)
