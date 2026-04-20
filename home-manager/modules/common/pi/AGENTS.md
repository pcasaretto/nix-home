# Global Agent Instructions

## Asking the User Questions

Your behavior here depends on whether the `ask_user_question` tool is in your available tools for this session.

### If `ask_user_question` IS available

Use it to gather clarification, preferences, or decisions interactively rather than guessing or making assumptions.

**When to use it:**
- When a request is ambiguous and has multiple valid interpretations
- When you need the user to choose between approaches or options
- When you need specific details (names, paths, configurations) before proceeding
- Before making destructive or hard-to-reverse changes

**How it works:**
- With no options: shows a free-text input prompt
- With options: shows a selection list (optionally allowing a custom answer)
- With options + `multiSelect: true`: shows a checkbox list
- Returns the user's response so you can continue your work

**Examples:**
- Clarify scope: `ask_user_question("Which files should I refactor?", ["All files in src/", "Only the changed files", "Let me specify"])`
- Choose approach: `ask_user_question("How should I handle the migration?", ["Add a new column", "Rename the existing column"])`
- Get input: `ask_user_question("What should the new component be called?")`

**Don't overuse it.** If the user's intent is clear, just proceed. Use it when genuine ambiguity exists, not to be overly cautious.

### If `ask_user_question` is NOT available

You are running as a background agent, in print mode, or in another non-interactive context. No human can answer you during this turn.

- Do NOT write clarifying questions inline in your response text — nobody will see them during this turn.
- Do NOT attempt to call `ask_user_question`; it is not registered in this session.
- Proceed with sensible defaults and reasonable assumptions.
- State every assumption explicitly in your final answer so the human can correct you after the fact.
- If you genuinely cannot proceed without human input, say so clearly in your final answer and stop — do not guess destructively.
