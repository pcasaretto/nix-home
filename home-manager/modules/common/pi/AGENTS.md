# Global Agent Instructions

## Asking the User Questions

You have an `ask_user_question` tool available. Use it to gather clarification, preferences, or decisions interactively rather than guessing or making assumptions.

**When to use it:**
- When a request is ambiguous and has multiple valid interpretations
- When you need the user to choose between approaches or options
- When you need specific details (names, paths, configurations) before proceeding
- Before making destructive or hard-to-reverse changes

**How it works:**
- With no options: shows a free-text input prompt
- With options: shows a selection list (optionally allowing a custom answer)
- Returns the user's response so you can continue your work

**Examples:**
- Clarify scope: `ask_user_question("Which files should I refactor?", ["All files in src/", "Only the changed files", "Let me specify"])`
- Choose approach: `ask_user_question("How should I handle the migration?", ["Add a new column", "Rename the existing column"])`
- Get input: `ask_user_question("What should the new component be called?")`

**Don't overuse it.** If the user's intent is clear, just proceed. Use it when genuine ambiguity exists, not to be overly cautious.
