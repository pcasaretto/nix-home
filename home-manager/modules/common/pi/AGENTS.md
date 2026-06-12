# Global Agent Instructions

## Hard Rule: Do Not Write From the Root World Worktree

Never create, modify, delete, format, generate, or otherwise write files from the root `world` worktree. This includes direct tool writes (`write`, `edit`), shell redirection, code generators, package manager scripts, formatters, tests or commands with write side effects, and any other operation that can change files.

Before any write-capable operation in a Shopify `world` checkout, verify that the current working directory is not the root `world` worktree. If it is the root `world` worktree, stop and move the work to an appropriate feature worktree or explicitly non-root worktree before making changes.

## Nix-Managed Dotfiles and Symlinks

Many files under the home directory are Home Manager-managed symlinks, often pointing into `/nix/store`, and cannot be edited directly. When changing dotfiles, agent configuration, or other symlinked files:

- Check whether the target file is a symlink before editing.
- If it points into `/nix/store` or another generated location, do not edit the live target directly.
- Locate and edit the source in the Nix/Home Manager configuration, usually under `/Users/paulo.casaretto/src/github.com/pcasaretto/nix-home`.
- After editing the source, apply it with the appropriate Home Manager or nix-darwin command, such as `home-manager switch --flake .#paulo.casaretto` from the nix-home repo.

## Asking the User Questions

Your behavior here depends on whether the `ask` tool is in your available tools for this session.

### If `ask` IS available

Use it to gather clarification, preferences, or decisions interactively rather than guessing or making assumptions.

**Hard rule:**
- NEVER ask the user a question by writing it in your text response.
- ALWAYS use the `ask` tool for clarifications, preferences, decisions, confirmations, and choices.
- Accumulate questions before asking whenever possible: identify all currently needed clarifications/decisions, then call `ask` once with an array of questions instead of asking serially across multiple turns.
- The only exception is a rhetorical question that does not need an answer.

**When to use it:**
- When a request is ambiguous and has multiple valid interpretations
- When you need the user to choose between approaches or options
- When you need specific details (names, paths, configurations) before proceeding
- Before making destructive or hard-to-reverse changes

**How it works:**
- Pass one question object or an array of question objects in `questions`
- Each question needs `id`, `question`, and a short 1-2 word `label`
- Omit `options` for free-form text input
- Use `options` for predefined choices; options can be strings or `{ label, value, description?, recommended? }` objects
- Questions are multi-select by default; set `multi: false` when the user should choose exactly one option
- Returns structured `answers`, `skipped`, and `unanswered` data so you can continue your work

**Examples:**
- Clarify scope: `ask({ questions: { id: "scope", label: "Scope", question: "Which files should I refactor?", multi: false, options: ["All files in src/", "Only the changed files", "Let me specify"] } })`
- Choose approach: `ask({ questions: { id: "migration", label: "Migration", question: "How should I handle the migration?", multi: false, options: ["Add a new column", "Rename the existing column"] } })`
- Get input: `ask({ questions: { id: "name", label: "Name", question: "What should the new component be called?" } })`

**Don't overuse it.** If the user's intent is clear, just proceed. Use it when genuine ambiguity exists, not to be overly cautious.

### If `ask` is NOT available

You are running as a background agent, in print mode, or in another non-interactive context. No human can answer you during this turn.

- Do NOT write clarifying questions inline in your response text — nobody will see them during this turn.
- Do NOT attempt to call `ask`; it is not registered in this session.
- Proceed with sensible defaults and reasonable assumptions.
- State every assumption explicitly in your final answer so the human can correct you after the fact.
- If you genuinely cannot proceed without human input, say so clearly in your final answer and stop — do not guess destructively.
