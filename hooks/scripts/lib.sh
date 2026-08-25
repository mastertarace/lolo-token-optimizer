#!/bin/bash
# Shared helpers for lolo-token-optimizer hook scripts.
# Load with: source "$(dirname "$0")/lib.sh"

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLUGIN_MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-/tmp/lolo-token-optimizer}"
mkdir -p "$STATE_DIR" 2>/dev/null || true

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# Read the hook's JSON payload from stdin exactly once, right here, in the
# top-level script process. `export` makes it visible to every later
# subshell (command substitutions like `x=$(json_field ...)` fork a
# subshell that inherits the environment but cannot write back to the
# parent) so a single stdin read is safely reused by every helper below.
if [[ -z "${HOOK_INPUT_JSON+x}" ]]; then
  HOOK_INPUT_JSON="$(cat)"
fi
export HOOK_INPUT_JSON

# read_setting <key> <default>
read_setting() {
  local key="$1" default="$2"
  if [[ "$HAVE_JQ" -eq 1 && -f "$PLUGIN_MANIFEST" ]]; then
    local val
    val=$(jq -r --arg k "$key" '.settings[$k] // empty' "$PLUGIN_MANIFEST" 2>/dev/null)
    [[ -n "$val" ]] && { echo "$val"; return; }
  fi
  echo "$default"
}

json_field() {
  local field="$1" default="${2:-}"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    local val
    val=$(printf '%s' "$HOOK_INPUT_JSON" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null)
    [[ -n "$val" && "$val" != "null" ]] && { echo "$val"; return; }
  fi
  echo "$default"
}

json_nested_field() {
  local path="$1" default="${2:-}"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    local val
    val=$(printf '%s' "$HOOK_INPUT_JSON" | jq -r "$path // empty" 2>/dev/null)
    [[ -n "$val" && "$val" != "null" ]] && { echo "$val"; return; }
  fi
  echo "$default"
}

deny_tool() {
  local reason="$1"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -n --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' \
      "$(printf '%s' "$reason" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$reason")"
  fi
  exit 0
}

inject_context() {
  local event="$1" text="$2"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    jq -n --arg ev "$event" --arg ctx "$text" '{
      hookSpecificOutput: {
        hookEventName: $ev,
        additionalContext: $ctx
      }
    }'
  fi
  exit 0
}

# Consecutive-failure counter, per session + agent, used to detect a
# subagent (typically a lightweight model) looping on the same failure.
failure_counter_file() {
  local session_id agent_id
  session_id=$(json_field "session_id" "nosession")
  agent_id=$(json_field "agent_id" "main")
  echo "$STATE_DIR/failures-${session_id}-${agent_id}.count"
}
