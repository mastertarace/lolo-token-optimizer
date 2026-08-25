# LoLo Token Optimizer v2

A Claude Code plugin that reduces token/cost overhead by enforcing
compression rules before subagent delegation, blocking raw reads of
oversized files, and cutting off subagents that loop on repeated tool
failures.

## Install (from GitHub)

Inside a Claude Code session, run:

```
/plugin marketplace add mastertarace/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

That's it — no download, no dependency to install, no setting to touch.
Full details and alternative install methods (local clone, quick
`--plugin-dir` testing) are in [Installation](#installation) below.

## Requirements

- Claude Code with plugin support (hooks + skills).
- `bash`.

Nothing else to install and nothing to configure: every hook script picks
its own JSON backend automatically, in this order:

1. `jq`, if present (fastest).
2. `python3`, if `jq` is missing — present on virtually every dev machine,
   so this is the realistic zero-config default.
3. A `grep`/`sed` best-effort for flat fields, only if neither exists.

All three paths implement the same behavior (read settings, read hook
fields, emit deny/context JSON), so the plugin is fully functional right
after `install.sh` with no package to install and no setting to touch.

## What it actually does

This plugin works entirely through **hooks** (`hooks/hooks.json`) plus one
manually-invocable **skill** (`skills/token-optimizer/`). There is no
slash command and no background daemon — everything runs as short-lived
shell scripts triggered by Claude Code hook events.

| Event | Script | Effect |
|---|---|---|
| `InstructionsLoaded` | `inject-compression-rules.sh` | Injects a short reminder of the compression rules (mission <= 15 words, context <= 120 tokens, prefer a lightweight model) into the conversation context. |
| `SubagentStart` | `subagent-start-context.sh` | Injects a compact-answering instruction into the subagent's own context when it starts. |
| `PreToolUse` (matcher `Read`) | `check-file-size.sh` | Estimates the target file's size in tokens (~4 bytes/token) against `maxFileTokenLimit`; denies the read with a message suggesting `grep`/`sed`/`awk` or a ranged read if it's over the limit. |
| `PreToolUse` (matcher `*`) | `guard-loop.sh` | Before any tool call, checks the consecutive-failure counter for the current session+agent; if it has reached `maxToolRetriesBeforeAbort`, denies the call. This is sticky: the counter is only cleared by a success or by session/subagent end, so every further tool call is denied too, not just the one that tripped the threshold. |
| `PostToolUseFailure` (matcher `*`) | `track-tool-failure.sh` | Increments the consecutive-failure counter. |
| `PostToolUse` (matcher `*`) | `reset-failure-counter.sh` | Clears the counter as soon as a tool call succeeds. |
| `SubagentStop` / `Stop` | `reset-failure-counter.sh` | Clears any leftover counter when a subagent or the session ends. |

State (failure counters) is kept as small files under
`$CLAUDE_PLUGIN_DATA` (or `/tmp/lolo-token-optimizer` if that variable
isn't set), one file per `session_id` + `agent_id` pair.

### Important limitation: there is no real "kill subagent" action

Claude Code's hook system does not expose an action that terminates a
running subagent outright — no hook action type, CLI command, or OS-level
handle to end it from outside. `guard-loop.sh` approximates the plugin's
goal ("cut off looping subagents") by **denying every tool call** once the
failure threshold is hit — not just the next one, but all of them, sticky,
until a tool call succeeds or the subagent/session ends. In practice this
starves the agent of tools, so it can only keep answering in plain text and
naturally wraps up its turn — but it is not a forced termination, and
nothing stops it from producing more text output while starved.

### Settings (`.claude-plugin/plugin.json`)

```json
{
  "settings": {
    "defaultEffort": "low",
    "maxFileTokenLimit": 10000,
    "maxToolRetriesBeforeAbort": 2
  }
}
```

- `defaultEffort`: mentioned in the `InstructionsLoaded` reminder only; it
  is not enforced programmatically (Claude Code doesn't expose a hook to
  force effort level).
- `maxFileTokenLimit`: token budget for a single `Read`, approximated as
  `size_in_bytes / 4`.
- `maxToolRetriesBeforeAbort`: consecutive tool failures allowed before
  `guard-loop.sh` denies the next call.

## The `token-optimizer` skill

`skills/token-optimizer/SKILL.md` lets you manually re-apply the same
compression rules mid-task (e.g. "optimize tokens before delegating this
batch"). It's a checklist, not an automated action — invoke it with
`/token-optimizer` (or let Claude invoke it when relevant).

## `cli.sh` — manual diagnostics

Not wired into Claude Code (plugins don't expose arbitrary CLI entry
points); run it directly from a shell for troubleshooting:

```bash
./cli.sh status   # show plugin version, settings, and any active failure counters
./cli.sh reset    # clear all failure counters
```

## Installation

Claude Code activates plugins through a marketplace registration — a plain
copy into `~/.claude/plugins/` is not enough by itself. This repo's root
`.claude-plugin/marketplace.json` makes it a self-contained, single-plugin
marketplace, so no separate listing repo is needed.

**From the published repo**, inside a Claude Code session:

```
/plugin marketplace add mastertarace/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

**From a local clone**, inside a Claude Code session:

```
/plugin marketplace add /path/to/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

**Quick local testing** without registering a marketplace at all:

```bash
claude --plugin-dir /path/to/lolo-token-optimizer
```

`./install.sh` additionally copies the repo into
`~/.claude/plugins/lolo-token-optimizer/` and marks the hook scripts
executable — convenient for running `cli.sh` or inspecting the installed
copy, but it does not by itself register or activate the plugin; still run
one of the `/plugin` commands above afterward.

## Verifying it works

1. `./cli.sh status` — confirms the manifest is readable and settings
   resolve correctly.
2. Start a Claude Code session in a project and check that the
   `InstructionsLoaded` reminder appears in context (visible via
   `/context` or session transcript, depending on Claude Code version).
3. Try reading a file larger than `maxFileTokenLimit * 4` bytes — the
   `Read` tool call should be denied with a message suggesting `grep`/
   ranged reads.
4. Force two consecutive tool failures in the same session/agent (e.g. two
   failing `Bash` commands) — the third tool call should be denied by
   `guard-loop.sh`.

## Directory layout

```
lolo-token-optimizer/
├── .claude-plugin/
│   └── plugin.json           # manifest: name, version, settings
├── hooks/
│   ├── hooks.json            # hook wiring (real Claude Code schema)
│   └── scripts/
│       ├── lib.sh                     # shared helpers (jq wrappers, state file paths)
│       ├── inject-compression-rules.sh
│       ├── subagent-start-context.sh
│       ├── check-file-size.sh
│       ├── guard-loop.sh
│       ├── track-tool-failure.sh
│       └── reset-failure-counter.sh
├── skills/
│   └── token-optimizer/
│       └── SKILL.md          # manually-invocable compression checklist
├── cli.sh                    # manual diagnostics (status/reset), not a slash command
├── install.sh                # copies the plugin into ~/.claude/plugins/
└── README.md
```

## Known constraints / non-goals

- Token counts are byte-based approximations, not an actual tokenizer —
  expect drift on non-English/code-heavy content.
- Hook behavior (available events, `hookSpecificOutput` fields) depends on
  the installed Claude Code version; test after upgrading.
- No automatic switching to a specific lightweight model — the
  `defaultEffort` setting and skill are reminders/checklists for the
  model, not an enforced routing mechanism.
