# Claude Code — lolo Token Optimizer

Claude Code skill designed to reduce token consumption by using a lightweight model for exploration and verification tasks, while keeping the main model for reasoning, complex implementation, and validation.

## Personal installation

Copy the `lolo-token-optimizer` folder into:

`~/.claude/skills/`

Which gives:

`~/.claude/skills/lolo-token-optimizer/SKILL.md`

### Automatic installation

Ask your Claude to install this Skill itself 😉

## Usage

Manual invocation:

`/lolo-token-optimizer`

The skill can also be loaded automatically by Claude Code when its description matches the task.

Configuration subcommands:

- `/lolo-token-optimizer SubagentName SUBAGENT_TYPE SUBAGENT_NAME` — rename a subagent role's display name.
- `/lolo-token-optimizer AllsSubagentEffortlevel SUBAGENT_TYPE EFFORT_LEVEL` — set a role's effort level (`low`/`medium`/`high`) by role type.
- `/lolo-token-optimizer AllsSubagentEffortlevel SUBAGENT_NAME EFFORT_LEVEL` — same, but targeting the role by its current display name.

`SUBAGENT_TYPE` is one of `Exploration/research`, `Verification/testing`, `Targeted debugging`. See the configuration tables in `SKILL.md` for details.

## Principle

- Haiku: exploration, research, simple analysis, verification.
- Main model: architecture, decisions, complex implementation, difficult debugging, final validation.
- No subagent if the main model already has the context and delegation would cost more than it saves.
- Subagent reasoning effort (low/medium/high) is configurable per role in the effort table in `SKILL.md`.

## How it works

The skill acts as a standing policy layer, not a one-shot tool: once loaded, it governs every delegation decision Claude Code makes for the rest of the task.

### 1. Classify before delegating

For each subtask, the skill first classifies it against two lists:

- **Delegate to Haiku**: mechanical/repetitive work, easily verifiable output, pure exploration, file/symbol/reference search, simple log or error analysis, test-existence checks, multi-file comparison, fact-gathering for the main model.
- **Keep on the main model**: architecture, design choices, multi-step reasoning, complex or cross-cutting changes, hard debugging, security, major migrations, fine-grained dependency understanding, final validation, choosing between competing technical solutions.

A subtask that isn't clearly exploratory/verifiable stays on the main model by default.

### 2. Skip delegation when it doesn't pay off

Even a classifiable subtask is kept local if: the context is already loaded, the subtask is very short, the expected output is tiny, or shipping context to a subagent would cost more than it saves. This is an explicit cost/benefit check, not a blanket "always delegate exploration" rule.

### 3. Configurable roles, names, and effort

Three subagent roles are defined — exploration/research, verification/testing, targeted debugging — each with:
- a **display name** (editable table, e.g. "Larbin Scout"), so status lines stay readable and brand-consistent;
- an **effort level** (editable table: low/medium/high), passed as the subagent's reasoning-effort parameter, so cost scales with how much reasoning the delegated subtask actually needs.

### 4. Parallelize independent work

When several subtasks are independent (e.g. log analysis + code search + test search), the skill launches them as parallel subagents instead of chaining them sequentially, then synthesizes the results on the main model.

### 5. Strict context hygiene per delegation

Each delegation is scoped tightly: only the necessary context is passed, the mission is precise, the requested output is short (no narrative summaries), and the subagent is never asked to redo the overall reasoning — only its specific piece.

### 6. Visible progress trail

Every delegation prints a status line before launch (`→ [Name]: <short mission>`) and one on completion (`✓ [Name]: <1-line finding>` or `✗ [Name]: <reason>` if the main model has to take it back). Parallel delegations print one line per subagent in each direction. Results are expected back in a fixed short format: files involved, finding, recommended action, verification result.

### 7. Workflow templates for common operations

The skill encodes fixed hand-off sequences instead of ad hoc delegation:
- **Code changes**: main model decides → Haiku researches if useful → main model implements → Haiku verifies independent pieces → main model does final validation.
- **Testing**: simple independent tests can be delegated; final validation of any significant change always stays on the main model — a subagent's passing test is never treated as sufficient proof for a complex change.
- **Debugging**: simple/local bugs can have Haiku search occurrences and suggest likely causes; complex bugs keep the reasoning on the main model, using Haiku only for targeted lookups.
- **Large repositories**: an initial lightweight Haiku pass maps relevant files, entry points, symbols, and associated tests before the main model decides what to actually change.

### 8. Guardrails against runaway delegation

- **No cascading subagents**: a subagent should not spawn further subagents except in exceptional cases — the skill enforces a flat `main model → Haiku → main model` shape rather than deep chains.
- **Gain estimation before delegating**: informally, `expected gain = work saved on the main model − context cost + cost of the subagent's result`; if that's small or uncertain, don't delegate.
- **Quality always wins over cost**: if a delegation risks losing important context, introducing an error, causing repeated back-and-forth, or producing an ambiguous result, the task stays on the main model regardless of potential token savings.

### 9. Decision summary

The skill always looks for the cheapest strategy that still yields a reliable result, in this order of preference: **direct** (main model, already has context) → **single Haiku delegation** (independent, worthwhile exploration/verification) → **parallel Haiku delegation** (several independent searches) → **main model** (reasoning, design, complex implementation, final validation).

## Changelog

- 2026-08-25: Added configurable subagent effort levels (low/medium/high) per role.
- 2026-08-25: Added detailed "How it works" section describing the full delegation logic.
- 2026-08-25: Added an "Automatic installation" step to the Installation section.
- 2026-08-25: Added `/lolo-token-optimizer SubagentName ...` and `/lolo-token-optimizer AllsSubagentEffortlevel ...` subcommands to rename subagents and set their effort level from the chat.
