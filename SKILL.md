---
name: lol-token-optimizer
description: Optimizes token usage and cost in Claude Code by deciding when to delegate a subtask to a lightweight subagent (Haiku) and when to keep the work on the main model. Use for development tasks, code exploration, log analysis, testing, and refactoring where cost reduction is relevant.
---

# Token Optimizer

You are responsible for optimizing the **quality / cost / context** trade-off when using Claude Code.

## Primary goal

Reduce token consumption without degrading result quality.

Do NOT automatically delegate every subtask. Delegation is only worthwhile if it reduces the main model's workload enough to offset the cost of the subagent's new context and the returned result.

## Subagent name configuration

Edit this table to change the displayed name of the subagents. The skill uses these names everywhere it delegates.

| Role | Display name |
|---|---|
| Exploration/research | Larbin Scout |
| Verification/testing | Larbin Inspector |
| Targeted debugging | Larbin Intello |

## Decision rule

Before delegating, classify the subtask:

### Prefer delegating to Haiku if it is

- mechanical or repetitive;
- easily verifiable;
- independent of architectural reasoning;
- primarily exploratory;
- limited to finding files, symbols, or references;
- simple log or error analysis;
- test verification;
- comparison of several files;
- fact-gathering needed by the main model.

Examples:
- finding where a function is defined;
- identifying the files related to a feature;
- analyzing a log to extract errors;
- searching for existing tests;
- checking which occurrences of an API exist;
- proposing a short list of files to modify.

### Keep on the main model if it involves

- architecture;
- design choices;
- multi-step reasoning;
- complex or cross-cutting modification;
- difficult debugging;
- security;
- major migration;
- fine-grained understanding of dependencies;
- final validation;
- deciding between several technical solutions.

## Do not delegate small trivial tasks

If the main model already has the necessary context and can answer quickly, work directly.

Avoid delegation when:

1. the necessary context is already loaded;
2. the subtask is very short;
3. the expected result is tiny;
4. the cost of transmitting context to the subagent risks exceeding the gain.

## Prefer parallel delegation

When several searches are independent, group them into parallel subtasks rather than running them sequentially.

Example:

- subagent 1: analyze the logs;
- subagent 2: search the relevant code;
- subagent 3: search the tests.

Then synthesize the results in the main model.

## Strict context control

When delegating:

- provide only the necessary context;
- give a precise mission;
- ask for a short answer;
- do not ask for a narrative summary;
- avoid transmitting unnecessary files;
- do not ask the subagent to redo the overall reasoning.

## Progress display

For each delegation, display a status line in the chat with the subagent's name (see configuration table above):

- before launch: `→ [Name]: <short mission>`
- on receiving the result: `✓ [Name]: <1-line finding>` (or `✗ [Name]: <reason>` if failed / taken back by the main model)

For parallel delegation, display one `→` line per subagent launched, then one `✓`/`✗` line per result received.

Recommended return format:

- `Files involved`
- `Finding`
- `Recommended action`
- `Verification result`

No long explanation unless necessary.

## Modification policy

By default, use lightweight subagents to **explore and verify**, not to make architectural decisions.

For a code modification:

1. main model: understand and decide;
2. Haiku: targeted research if useful;
3. main model: implement;
4. Haiku: simple verifications if independent;
5. main model: final validation and correction.

If a modification handed to Haiku becomes complex or ambiguous, take it back into the main model.

## Testing policy

Simple, independent tests can be delegated.

Final validation of a significant modification must stay on the main model.

Never consider a test passed by a subagent sufficient to validate a complex modification.

## Debugging policy

For a simple, local bug:

- Haiku can search for occurrences and identify likely causes.

For a complex bug:

- the main model retains the reasoning;
- Haiku can be used only for targeted research.

## Avoid cascading delegation

Do not create a subagent that itself creates other subagents, except in exceptional cases.

The goal is to limit:

`main model -> subagent -> subagent -> ...`

Prefer:

`main model -> Haiku -> main model`

## Qualitative gain estimate

Before a delegation, estimate:

`expected gain = work saved on the main model - context cost + cost of the subagent's result`

If the gain is small or uncertain, do not delegate.

## Special rule for large repositories

In a large repository, an initial lightweight exploration phase is often worthwhile.

Use Haiku to:

- map the relevant files;
- identify entry points;
- search for symbols;
- identify associated tests.

Then let the main model decide what to modify.

## Never sacrifice quality to save tokens

Cost is a secondary optimization relative to result correctness.

If a delegation risks:

- losing important context;
- introducing an error;
- multiplying back-and-forth exchanges;
- producing an ambiguous analysis;

stay on the main model.

## Expected outcome

For each task, look for the minimal strategy that yields a reliable result:

**Direct → if simple and already contextualized.**

**Haiku → if exploration/verification is independent and worthwhile.**

**Parallel Haiku → if several independent searches.**

**Main model → for reasoning, design, complex implementation, and final validation.**

## Manual invocation

This skill can also be invoked with:

`/lolo-token-optimizer`

If arguments are provided, use them as additional context to determine the strategy:

`$ARGUMENTS`
