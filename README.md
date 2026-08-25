# Claude Code — lolo Token Optimizer

Claude Code skill designed to reduce token consumption by using a lightweight model for exploration and verification tasks, while keeping the main model for reasoning, complex implementation, and validation.

## Personal installation

Copy the `lolo-token-optimizer` folder into:

`~/.claude/skills/`

Which gives:

`~/.claude/skills/lolo-token-optimizer/SKILL.md`

## Usage

Manual invocation:

`/lolo-token-optimizer`

The skill can also be loaded automatically by Claude Code when its description matches the task.

## Principle

- Haiku: exploration, research, simple analysis, verification.
- Main model: architecture, decisions, complex implementation, difficult debugging, final validation.
- No subagent if the main model already has the context and delegation would cost more than it saves.
- Subagent reasoning effort (low/medium/high) is configurable per role in the effort table in `SKILL.md`.

## Changelog

- 2026-08-25: Added configurable subagent effort levels (low/medium/high) per role.
