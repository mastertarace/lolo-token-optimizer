#!/bin/bash
# Shared helpers for lolo-token-optimizer hook scripts.
# Load with: source "$(dirname "$0")/lib.sh"
#
# JSON handling has three tiers so the plugin works with zero setup:
#   1. jq, if installed (fastest, most correct).
#   2. python3, almost always present on a dev machine (used as the
#      zero-config default fallback).
#   3. A crude grep/sed best-effort for flat top-level string/number
#      fields, only reached if neither jq nor python3 exists.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLUGIN_MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-/tmp/lolo-token-optimizer}"
mkdir -p "$STATE_DIR" 2>/dev/null || true

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1
HAVE_PY3=0
command -v python3 >/dev/null 2>&1 && HAVE_PY3=1

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
# Reads .settings[key] from the plugin manifest.
read_setting() {
  local key="$1" default="$2"
  if [[ ! -f "$PLUGIN_MANIFEST" ]]; then
    echo "$default"; return
  fi
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    local val
    val=$(jq -r --arg k "$key" '.settings[$k] // empty' "$PLUGIN_MANIFEST" 2>/dev/null)
    [[ -n "$val" ]] && { echo "$val"; return; }
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    local val
    val=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    v = data.get("settings", {}).get(sys.argv[2])
    print(v if v is not None else "")
except Exception:
    print("")
' "$PLUGIN_MANIFEST" "$key" 2>/dev/null)
    [[ -n "$val" ]] && { echo "$val"; return; }
  else
    local val
    val=$(grep -A5 '"settings"' "$PLUGIN_MANIFEST" 2>/dev/null \
      | grep -m1 "\"$key\"" \
      | sed -E 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"?([^",}]*)"?.*/\1/')
    [[ -n "$val" ]] && { echo "$val"; return; }
  fi
  echo "$default"
}

# json_field <top-level key> <default>
# Reads a flat top-level field from the cached hook stdin JSON.
json_field() {
  local field="$1" default="${2:-}"
  local val=""
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    val=$(printf '%s' "$HOOK_INPUT_JSON" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null)
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    val=$(printf '%s' "$HOOK_INPUT_JSON" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
    v = data.get(sys.argv[1])
    print(v if v is not None else "")
except Exception:
    print("")
' "$field" 2>/dev/null)
  else
    val=$(printf '%s' "$HOOK_INPUT_JSON" \
      | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
  fi
  [[ -n "$val" && "$val" != "null" ]] && { echo "$val"; return; }
  echo "$default"
}

# json_path_field <dotted.path> <default>
# Reads a nested field (e.g. "tool_input.file_path") from the cached hook
# stdin JSON.
json_path_field() {
  local path="$1" default="${2:-}"
  local val=""
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    val=$(printf '%s' "$HOOK_INPUT_JSON" | jq -r ".${path} // empty" 2>/dev/null)
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    val=$(printf '%s' "$HOOK_INPUT_JSON" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for key in sys.argv[1].split("."):
        if not isinstance(data, dict):
            data = None
            break
        data = data.get(key)
    print(data if data is not None else "")
except Exception:
    print("")
' "$path" 2>/dev/null)
  else
    local leaf="${path##*.}"
    val=$(printf '%s' "$HOOK_INPUT_JSON" \
      | grep -o "\"$leaf\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
  fi
  [[ -n "$val" && "$val" != "null" ]] && { echo "$val"; return; }
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
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": sys.argv[1],
    }
}))
' "$reason"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' \
      "$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')"
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
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": sys.argv[1],
        "additionalContext": sys.argv[2],
    }
}))
' "$event" "$text"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}' \
      "$event" "$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')"
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
