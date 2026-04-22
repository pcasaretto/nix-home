# Subagent Pattern Guide

> A practical guide to pi's `subagent` tool based on 18 production calls across 11 sessions
> (Feb 4 – Mar 5, 2026). Evidence sourced from `~/.pi/agent/sessions/` JSONL logs.

---

## Table of Contents

1. [Overview & Statistics](#overview--statistics)
2. [Pattern Catalog](#pattern-catalog)
   - [Pattern 1: Multi-Perspective PR Review](#pattern-1-multi-perspective-pr-review)
   - [Pattern 2: Research & Exploration](#pattern-2-research--exploration)
   - [Pattern 3: Lightweight Recon](#pattern-3-lightweight-recon)
   - [Pattern 4: Document Review](#pattern-4-document-review)
   - [Pattern 5: Spec Analysis](#pattern-5-spec-analysis)
   - [Pattern 6: Creative / No-Tool Tasks](#pattern-6-creative--no-tool-tasks)
3. [Decision Tree](#decision-tree)
4. [Parameter Recommendations](#parameter-recommendations)
5. [Anti-Patterns](#anti-patterns)
6. [Quick Reference](#quick-reference)

---

## Overview & Statistics

### Call Distribution (18 total calls)

| Mode | Count | % | Typical Use |
|------|-------|---|-------------|
| **Parallel** (`tasks`) | 12 | 67% | PR reviews, multi-angle research |
| **Single** (`task`) | 6 | 33% | Focused research, recon, creative |
| **Chain** (`chain`) | 0 | 0% | Not observed in production (yet) |

### Subtasks Spawned

- **PR review calls** (7 calls): avg **7 parallel tasks** each → 49 subtasks
- **Research calls** (5 calls): 1–3 tasks each → 9 subtasks
- **Recon calls** (4 calls): 1 task each → 4 subtasks
- **Total subtasks spawned**: ~62 across 18 invocations

### Agent Names Used

| Agent Name | Occurrences | Pattern |
|------------|-------------|---------|
| `architecture-strategist` | 6 | PR review |
| `security-sentinel` | 7 | PR review |
| `performance-oracle` | 7 | PR review |
| `code-simplicity-reviewer` | 7 | PR review |
| `agent-native-reviewer` | 7 | PR review |
| `learnings-researcher` | 7 | PR review + research |
| `kieran-rails-reviewer` | 4 | PR review |
| `pattern-recognition-specialist` | 2 | PR review |
| `repo-research-analyst` | 3 | Research |
| `document-review` | 1 | Doc review |
| `spec-flow-analyzer` | 1 | Spec analysis |

### Model Distribution

| Model | Usage | Context |
|-------|-------|---------|
| `default` (omitted) | 14 calls | PR reviews, research, doc review |
| `claude-haiku-4-5` | 4 calls | Recon, file listing, creative |

---

## Pattern Catalog

### Pattern 1: Multi-Perspective PR Review

**When to use:** Reviewing a pull request from multiple angles simultaneously.
**Frequency:** 7 of 18 calls (39%) — the dominant pattern.
**Mode:** Parallel with 6–8 tasks.

#### Template

```json
{
  "tasks": [
    {
      "agent": "architecture-strategist",
      "task": "Review PR #XXXXX 'TITLE' in REPO.\n\n## PR Summary\nDESCRIPTION\n\n## Files Changed\n1. `path/to/file.rb` - What changed (+lines/-lines)\n\n## Existing Patterns for Comparison\nSHOW_SIMILAR_CODE_IN_CODEBASE\n\n## Key Design Decisions\nLIST_DECISIONS\n\n## Diff\n```language\nACTUAL_CODE_DIFF\n```\n\nAnalyze architectural patterns, DRY extraction, concern design.",
      "cwd": "/path/to/zone"
    },
    {
      "agent": "security-sentinel",
      "task": "Security review of PR #XXXXX 'TITLE'.\n\n## Security-relevant code:\nCODE_BLOCKS\n\nCheck for: input validation, injection risks, error information leakage, authorization, data integrity, race conditions."
    },
    {
      "agent": "performance-oracle",
      "task": "Performance review of PR #XXXXX 'TITLE'.\n\nAnalyze: N+1 queries, caching opportunities, unnecessary allocations, database index usage, Kafka consumer throughput."
    },
    {
      "agent": "code-simplicity-reviewer",
      "task": "Review PR #XXXXX for unnecessary complexity, YAGNI violations, over-engineering. Is the abstraction level right? Could this be simpler?"
    },
    {
      "agent": "agent-native-reviewer",
      "task": "Review PR #XXXXX from an agent-accessibility perspective. Is the code easy for AI agents to understand, modify, and test? Are there clear patterns?"
    },
    {
      "agent": "learnings-researcher",
      "task": "Search the codebase for existing patterns related to THIS_FEATURE. Look for past solutions, anti-patterns, and team conventions. Use grep/find to search."
    }
  ]
}
```

#### Key Characteristics (from production)

1. **Every PR review task includes the FULL diff inline** — subagents don't have access to git, so the diff must be embedded in the task description
2. **Existing patterns are included for comparison** — the orchestrating agent reads similar code first and includes it as context
3. **Each agent gets a focused lens**: architecture, security, performance, simplicity, agent-friendliness, and prior art
4. **`cwd` is set on the first task** pointing to the relevant zone/directory
5. **No model override** — uses the default model for review depth
6. **No tools specified** — defaults are sufficient since all context is in the prompt

#### Actual Production Example (PR #365131)

```json
{
  "tasks": [
    {
      "agent": "architecture-strategist",
      "task": "Review PR #365131 '[Organizations] Add Monorail consumer for shop subscription changed event'...\n\n**EXISTING PATTERNS for comparison:**\n`PlanChangeConsumer` (existing, very similar purpose):\n- Uses CheckSidekiqQueueThrottle (NOT Hedwig)\n- Listens to shopify.shops.subscription.change with format json\n...\n\n**KEY QUESTIONS:**\n1. Why create a nearly-duplicate processor? Both enqueue the same job.\n2. start_from_position = 'latest' means messages before deployment are lost.\n3. Missing JSON.parse unlike RetailAddon processor.\n4. Error handling swallows exceptions.\n5. Missing WARNING comment about consumer_group_name.",
      "cwd": "/Users/paulo.casaretto/world/trees/root/src/areas/platforms/organizations"
    },
    {
      "agent": "security-sentinel",
      "task": "Security review of PR #365131... [full code blocks embedded]... Check for: input validation, injection risks, error information leakage, authorization, data integrity, race conditions."
    },
    {
      "agent": "performance-oracle",
      "task": "Performance review of PR #365131... [consumer config and code embedded]"
    },
    {
      "agent": "pattern-recognition-specialist",
      "task": "Compare PR #365131 against ALL similar consumers in the codebase... [4 existing consumers listed with full code]"
    },
    {
      "agent": "code-simplicity-reviewer",
      "task": "Simplicity review... Is this PR introducing unnecessary complexity?"
    },
    {
      "agent": "agent-native-reviewer",
      "task": "Agent-accessibility review... Can an AI agent easily work with this code?"
    },
    {
      "agent": "learnings-researcher",
      "task": "Search for past solutions related to Kafka consumers, Monorail, shop subscription events..."
    }
  ]
}
```

#### Variant: Kieran Rails Reviewer

4 of 7 PR reviews included a `kieran-rails-reviewer` agent — a persona-based reviewer applying specific Rails conventions:

```json
{
  "agent": "kieran-rails-reviewer",
  "task": "Review as a senior Rails developer focused on Rails idioms, convention over configuration, proper use of concerns, ActiveRecord patterns..."
}
```

---

### Pattern 2: Research & Exploration

**When to use:** Deep-diving into a codebase, API, or documentation to gather information for a task.
**Frequency:** 5 of 18 calls (28%).
**Mode:** Single or Parallel (2–3 tasks).

#### Template: Single Focused Research

```json
{
  "agent": "repo-research-analyst",
  "task": "Understand existing patterns related to TOPIC. Look for:\n1. Specific thing to find\n2. Another specific thing\n3. How X works\n4. Extension points for Y\n\nCheck these key docs:\n- /path/to/doc1.md\n- /path/to/doc2.md\n- /path/to/examples/\n\nFocus on SPECIFIC_ASPECT."
}
```

#### Template: Parallel Multi-Source Research

```json
{
  "tasks": [
    {
      "agent": "repo-research-analyst",
      "task": "Research patterns for FEATURE_X. Focus on: 1) How component A works 2) Pattern for B 3) How events deliver data 4) Theme access patterns 5) Gotchas with Z. Check docs at /path/to/docs/ — especially file1.md, file2.md, and examples like example1.ts, example2.ts"
    },
    {
      "agent": "learnings-researcher",
      "task": "Search docs/solutions/ for past learnings related to: TOPIC_A, TOPIC_B, TOPIC_C"
    }
  ]
}
```

#### Template: External + Internal Research

```json
{
  "tasks": [
    {
      "task": "Read the internal documentation completely. Read /path/to/docs.md fully, then read referenced examples. Return the FULL content.",
      "tools": ["read", "bash"],
      "model": "claude-haiku-4-5"
    },
    {
      "task": "Fetch and examine the GitHub repository https://github.com/ORG/REPO. Use curl to get the raw README, then use the API to list files and fetch main source files. Return ALL content.",
      "tools": ["bash"]
    }
  ]
}
```

#### Key Characteristics

1. **Explicit file paths in the task** — tell the subagent exactly where to look
2. **Numbered checklist of things to find** — structured investigation
3. **"Return the FULL content"** — prevents subagents from over-summarizing
4. **Research pairs well with `learnings-researcher`** in parallel

---

### Pattern 3: Lightweight Recon

**When to use:** Quick file discovery, directory listing, simple searches.
**Frequency:** 4 of 18 calls (22%).
**Mode:** Single with `claude-haiku-4-5`.

#### Template

```json
{
  "task": "List all TYPE files in this repository and give a brief summary of what each one does. Be concise — one line per file.",
  "model": "claude-haiku-4-5",
  "tools": ["read", "bash", "find", "ls"]
}
```

#### Template: Codebase Audit

```json
{
  "task": "This is a REPO_TYPE repository at PATH.\n\nYour job: find all THING_TO_FIND currently defined in this repo (under PATH/) and for each one, report:\n1. The filename\n2. What it does\n3. Whether it's wired into the config\n\nBe thorough — read each file and the config.",
  "model": "claude-haiku-4-5",
  "tools": ["read", "bash", "find", "ls"]
}
```

#### Key Characteristics

1. **Always uses `claude-haiku-4-5`** — cost-efficient for simple tasks
2. **Explicit tool list**: `["read", "bash", "find", "ls"]` — read-only tools
3. **Short, direct task descriptions** — no elaborate context needed
4. **One-line-per-item output format** requested for easy consumption

---

### Pattern 4: Document Review

**When to use:** Reviewing/improving a markdown document, brainstorm, or spec.
**Frequency:** 1 of 18 calls.
**Mode:** Single.

#### Template

```json
{
  "agent": "document-review",
  "task": "Review and improve the document at PATH. This is a DESCRIPTION_OF_DOCUMENT. Apply structured self-review to improve clarity, completeness, and identify any gaps."
}
```

#### Key Characteristics

1. **No tools or model specified** — uses defaults for full reasoning capability
2. **Document path provided directly** — subagent reads and reviews
3. **Clear review criteria**: clarity, completeness, gaps

---

### Pattern 5: Spec Analysis

**When to use:** Analyzing a feature spec for edge cases, flow completeness, and technical gaps.
**Frequency:** 1 of 18 calls.
**Mode:** Single.

#### Template

```json
{
  "agent": "spec-flow-analyzer",
  "task": "Analyze the following feature spec for user flow completeness, edge cases, and gaps:\n\n**Feature:** FEATURE_DESCRIPTION\n\n**Trigger events:** EVENT_A → ACTION, EVENT_B → ACTION\n\n**Technical context:** TECHNICAL_DETAILS\n\n**Key flows to analyze:**\n1. Normal flow: A → B → C\n2. Error case: A → failure\n3. Edge case: rapid succession\n4. Edge case: very small input\n5. Edge case: very large input\n6. Edge case: resize/reflow\n...\n\n**Research findings:**\n- FINDING_1\n- FINDING_2"
}
```

#### Key Characteristics

1. **Numbered flow list** — explicit scenarios to analyze
2. **Research findings included** — prior knowledge embedded in the prompt
3. **Technical context provided** — subagent doesn't need to discover it
4. **No tools needed** — pure analysis task

---

### Pattern 6: Creative / No-Tool Tasks

**When to use:** Tasks requiring pure generation without any tool access.
**Frequency:** 1 of 18 calls.
**Mode:** Single with empty tools array.

#### Template

```json
{
  "task": "CREATIVE_PROMPT. Output only the result, nothing else.",
  "model": "claude-haiku-4-5",
  "tools": []
}
```

#### Actual Production Example

```json
{
  "task": "Write a single haiku poem (5-7-5 syllable structure) about the relationship between a conductor and an orchestra — where the conductor holds all the context and knowledge, and the musicians are specialized workers who each receive just the right notes to play. Make it elegant and subtle. Output only the haiku, nothing else.",
  "model": "claude-haiku-4-5",
  "tools": []
}
```

#### Key Characteristics

1. **`tools: []`** — explicitly empty, no tool access
2. **`claude-haiku-4-5`** — sufficient for creative tasks, cost-efficient
3. **"Output only X, nothing else"** — constrains output format

---

## Decision Tree

```
Need to delegate work to subagent(s)?
│
├─ Is it a PR review?
│  └─ YES → Pattern 1: Multi-Perspective PR Review
│     • 6-8 parallel tasks
│     • Embed full diff + existing patterns in each task
│     • Use agent names: architecture, security, performance, simplicity, agent-native, learnings
│     • No model override (use default for depth)
│
├─ Do you need information from multiple sources?
│  └─ YES → Pattern 2: Parallel Research
│     • 2-3 parallel tasks
│     • Each task targets different source (docs, codebase, external)
│     • Include explicit file paths
│     • Request "FULL content" to prevent summarization
│
├─ Do you need a quick file listing or simple search?
│  └─ YES → Pattern 3: Lightweight Recon
│     • Single task
│     • model: "claude-haiku-4-5"
│     • tools: ["read", "bash", "find", "ls"]
│     • Short, direct task description
│
├─ Do you need to review/improve a document?
│  └─ YES → Pattern 4: Document Review
│     • Single task
│     • agent: "document-review"
│     • No model/tools override
│
├─ Do you need to analyze a spec or design?
│  └─ YES → Pattern 5: Spec Analysis
│     • Single task
│     • agent: "spec-flow-analyzer"
│     • Embed all context + numbered flow list
│     • No tools needed
│
└─ Is it a pure generation task (no tools needed)?
   └─ YES → Pattern 6: Creative / No-Tool
      • Single task
      • model: "claude-haiku-4-5"
      • tools: []
      • Constrain output format explicitly
```

---

## Parameter Recommendations

### Model Selection

| Scenario | Model | Rationale |
|----------|-------|-----------|
| PR review (any perspective) | `default` (omit) | Needs deep reasoning about code |
| Research & exploration | `default` (omit) | Needs to synthesize complex info |
| Document/spec review | `default` (omit) | Needs nuanced analysis |
| File listing / recon | `claude-haiku-4-5` | Simple task, cost-efficient |
| Code search / grep | `claude-haiku-4-5` | Mechanical task |
| Creative generation | `claude-haiku-4-5` | Sufficient quality, fast |

**Rule of thumb:** Use `claude-haiku-4-5` when the task is *mechanical* (find, list, grep, format). Use the default when the task requires *judgment* (review, analyze, design).

### Tools Selection

| Scenario | Tools | Rationale |
|----------|-------|-----------|
| PR review | `default` (omit) | Context embedded in task; rarely needs tools |
| Read-only recon | `["read", "bash", "find", "ls"]` | Prevents accidental writes |
| Research with file reading | `["read", "bash"]` | Needs to read docs |
| Research with external APIs | `["bash"]` | Needs curl for GitHub/APIs |
| Pure analysis / creative | `[]` | No tools needed |
| Implementation tasks | `default` (omit) | Needs full tool access |

**Rule of thumb:** Restrict tools to the minimum needed. Read-only tasks should not have `edit` or `write`.

### CWD Usage

| Scenario | CWD | Rationale |
|----------|-----|-----------|
| PR review | Set on first task to zone directory | Gives filesystem context |
| Repo-specific research | Set via `cwd` parameter | Scopes file operations |
| General research | Omit | Not relevant |
| Cross-repo work | Set per-task in parallel | Different repos per task |

**Production evidence:** Only 2 of 18 calls used `cwd` — both for PR reviews pointing to the specific zone in the World monorepo.

### Agent Names

Agent names are **descriptive labels** — they have no functional effect but serve as:
1. **Self-documentation** in session logs
2. **Persona framing** in the task context
3. **Result identification** when aggregating parallel outputs

Use descriptive, hyphenated names: `architecture-strategist`, `security-sentinel`, `repo-research-analyst`.

---

## Anti-Patterns

### ❌ 1. Not Embedding Context in PR Review Tasks

**Bad:**
```json
{
  "agent": "security-sentinel",
  "task": "Review PR #12345 for security issues."
}
```

**Good:**
```json
{
  "agent": "security-sentinel",
  "task": "Security review of PR #12345 'Add user auth'.\n\n## Code:\n```ruby\ndef authenticate(token)\n  User.find_by(token: token)\nend\n```\n\nCheck for: SQL injection, timing attacks, token validation."
}
```

**Why:** Subagents have isolated context windows. They can't see the PR, the diff, or the codebase unless you embed it. Every production PR review included the FULL diff and existing patterns inline.

### ❌ 2. Using Default Model for Simple Recon

**Bad:**
```json
{
  "task": "List all .nix files in this repo"
}
```

**Good:**
```json
{
  "task": "List all .nix files in this repo",
  "model": "claude-haiku-4-5",
  "tools": ["read", "bash", "find", "ls"]
}
```

**Why:** Simple file listing doesn't need the full model. Haiku is 10-20x cheaper and equally capable for mechanical tasks.

### ❌ 3. Using Chain Mode When Parallel Works

**Bad (sequential when tasks are independent):**
```json
{
  "chain": [
    {"task": "Read the architecture docs"},
    {"task": "Read the security policy"},
    {"task": "Read the performance guidelines"}
  ]
}
```

**Good (parallel since tasks are independent):**
```json
{
  "tasks": [
    {"task": "Read the architecture docs"},
    {"task": "Read the security policy"},
    {"task": "Read the performance guidelines"}
  ]
}
```

**Why:** Chain mode runs sequentially. Independent reads should be parallel. In production, 0 of 18 calls used chain mode — parallel was always preferred.

### ❌ 4. Vague Task Descriptions

**Bad:**
```json
{
  "task": "Look into the billing code"
}
```

**Good:**
```json
{
  "task": "Find all billing-related Kafka consumers in areas/platforms/billing/. For each one, report: 1) The consumer class name 2) What topic it listens to 3) What format it uses 4) What processor it delegates to 5) Error handling approach. Check app/consumers/ and config/active_kafka_consumers.yml."
}
```

**Why:** Subagents have fresh context windows with zero prior knowledge. Prescriptive, specific instructions with exact paths and numbered deliverables produce far better results.

### ❌ 5. Too Many Parallel Tasks

**Bad:**
```json
{
  "tasks": [
    {"task": "Review architecture"},
    {"task": "Review security"},
    {"task": "Review performance"},
    {"task": "Review testing"},
    {"task": "Review documentation"},
    {"task": "Review naming"},
    {"task": "Review error handling"},
    {"task": "Review logging"},
    {"task": "Review monitoring"},
    {"task": "Review deployment"}
  ]
}
```

**Good:** Keep parallel tasks to **6-8 maximum**. Production PR reviews used 6-8 tasks. The max allowed is 8.

**Why:** Each parallel task gets its own context window and API call. Diminishing returns above 8 tasks, and some perspectives can be combined.

### ❌ 6. Giving Write Tools to Research Tasks

**Bad:**
```json
{
  "task": "Research the authentication patterns in this codebase",
  "tools": ["read", "bash", "edit", "write"]
}
```

**Good:**
```json
{
  "task": "Research the authentication patterns in this codebase",
  "tools": ["read", "bash", "find", "ls"]
}
```

**Why:** Research tasks should be read-only. Restricting tools prevents accidental side effects and makes the intent clear.

---

## Quick Reference

### Minimal Parallel PR Review

```json
{
  "tasks": [
    {"agent": "architecture-strategist", "task": "DIFF + architecture analysis"},
    {"agent": "security-sentinel", "task": "DIFF + security review"},
    {"agent": "performance-oracle", "task": "DIFF + performance review"},
    {"agent": "code-simplicity-reviewer", "task": "DIFF + simplicity check"},
    {"agent": "agent-native-reviewer", "task": "DIFF + agent-friendliness"},
    {"agent": "learnings-researcher", "task": "Search codebase for related patterns"}
  ]
}
```

### Minimal Research

```json
{
  "agent": "repo-research-analyst",
  "task": "Research TOPIC. Check: /path/to/file1, /path/to/file2. Report: item1, item2, item3."
}
```

### Minimal Recon

```json
{
  "task": "Find all X in /path/to/dir/",
  "model": "claude-haiku-4-5",
  "tools": ["read", "bash", "find", "ls"]
}
```

### Minimal Creative

```json
{
  "task": "Generate X. Output only the result.",
  "model": "claude-haiku-4-5",
  "tools": []
}
```

---

## Evidence Sources

All patterns documented above were extracted from actual session logs at:
`~/.pi/agent/sessions/`

| Session Directory | Calls | Context |
|-------------------|-------|---------|
| `--Users-paulo.casaretto-world--/` | 5 | PR reviews (#365131, #373244, #373811, #373911, #430396) |
| `--...-nix-home--/` | 9 | Research, recon, doc review, spec analysis |
| `--...-billing--/` | 1 | PR review (#258654) |
| `--Users-paulo.casaretto--/` | 3 | PR review (#457330), research |
| **Total** | **18** | **11 unique sessions** |

Tool usage across all sessions for comparison:
- `bash`: 530 calls
- `read`: 111 calls
- `edit`: 42 calls
- `write`: 24 calls
- `todo`: 21 calls
- `ask_user_question`: 19 calls
- **`subagent`: 18 calls** (7th most used)
