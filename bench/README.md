# Bench: token savings estimate

Two ways to measure what the plugin actually saves. Start with the
synthetic estimator; it's free and instant. Move to the real-session
method when you want an exact, non-approximated number.

## 1. Synthetic estimator (no API calls, instant)

```bash
python3 bench/estimate_savings.py
python3 bench/estimate_savings.py --baseline-retries 10   # override the assumption
```

What it measures, and how:

- **File-size guard**: for each file in `fixtures/files/` that's over
  `maxFileTokenLimit`, compares "read the whole file" (real file size on
  disk) against "deny message + `grep` for a representative pattern" (real
  `grep` output, run for real against the fixture). `fixtures/files/manifest.json`
  documents which pattern is used for which file and why. One fixture
  (`small_config.py`) stays under the limit on purpose, as a control case
  showing the hook doesn't fire (and doesn't cost anything) when it
  shouldn't.
- **Loop guard**: prices one wasted retry using the real byte size of
  `fixtures/failed_attempt.txt` (a representative failed-tool-call
  transcript), then compares an assumed baseline retry count (how many
  times a subagent might blindly retry without the guard — override with
  `--baseline-retries`, default 6) against `maxToolRetriesBeforeAbort` real
  attempts plus cheap sticky denials for the rest.

Every number is either a real measurement (file size, grep output size) or
an explicitly labeled assumption (`--baseline-retries`). Token counts use
the plugin's own approximation, ~4 bytes/token — the same one
`hooks/scripts/lib.sh` uses at runtime — so the estimate is internally
consistent with what the hooks themselves compute, not a claim about an
exact tokenizer count. Treat the output as "this is what the mechanism
saves on this fixture set", not a universal percentage.

## 2. Real-session method (exact, costs real API tokens)

For an exact number instead of an estimate, run the same task twice in
real Claude Code sessions — once with the plugin installed, once without —
and diff the actual token usage from the session transcripts.

1. Disable the plugin (`/plugin uninstall lolo-token-optimizer` or start
   without `--plugin-dir`) and run your task. Note the session's
   `transcript_path` (shown by Claude Code, or find it under
   `~/.claude/projects/.../*.jsonl`).
2. Re-enable the plugin and run the *same* task again from a fresh
   session. Note that transcript too.
3. Extract usage from both:

   ```bash
   python3 bench/extract_usage.py /path/to/baseline.jsonl /path/to/with_plugin.jsonl
   ```

   This prints, per transcript: turn count, input tokens, output tokens,
   cache-read tokens, cache-creation tokens — pulled directly from the
   `usage` field Claude Code already records on each turn. Compare the two
   lines yourself; the script does not compute a diff, since "the same
   task" is never perfectly identical between two live runs (the model can
   phrase things differently, take a different tool order, etc.) and a
   fabricated single percentage would overstate precision that doesn't
   exist here.

This method is the ground truth, but it costs whatever the two real
sessions cost and requires you to actually reproduce comparable tasks by
hand — the synthetic estimator above is the practical default for a quick
check.
