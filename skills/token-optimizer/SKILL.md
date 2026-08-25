---
name: token-optimizer
description: Manually applies the lolo-token-optimizer plugin's compression and delegation rules (short mission, minimal context, prefer a lightweight model) to the current task.
---

# Token Optimizer

This skill manually applies the rules that the plugin otherwise reminds you
of automatically via the `InstructionsLoaded` hook. Invoke it when you want
to force a token-optimization pass on the current task, for example before
delegating a large research batch to a subagent.

## Compression rules

1. **Subagent mission <= 15 words.** One sentence, one goal, no narrative
   context ("find X in Y", not "I'd like you to explore...").
2. **Context passed to the subagent <= 120 tokens.** Don't copy whole chunks
   of the conversation; summarize into a handful of useful facts.
3. **Lightweight model by default.** For code reading, symbol search, log
   analysis, or any mechanical work, prefer a fast/cheap model (e.g. Haiku)
   over the main model.
4. **No blind retries.** If a subagent fails twice in a row on the same
   action (see the `maxToolRetriesBeforeAbort` setting), stop that approach
   and report the condensed error instead of trying a third time.
5. **No raw reads of large files.** Beyond `maxFileTokenLimit` estimated
   tokens (the `PreToolUse`/`Read` hook blocks this automatically), use a
   targeted extraction: `grep -n`, `sed -n 'a,bp'`, or a ranged read
   (offset/limit) instead of the whole file.

## When to use it

- Before delegating to several subagents in parallel, to check each mission
  respects the limits above.
- When a session grows long and context starts to weigh it down.
- On explicit user request ("optimize tokens", "compress the context before
  delegating").

## What this skill does not do

- It does not automatically modify code or project files.
- It does not replace the `InstructionsLoaded` hook (which already reminds
  the model of these rules on every instructions load): it's for deliberate,
  one-off application mid-task.
