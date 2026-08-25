#!/bin/bash
# Manual diagnostic tool for lolo-token-optimizer.
# Usage: ./cli.sh status | ./cli.sh reset
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-/tmp/lolo-token-optimizer}"

usage() {
  echo "Usage: $0 {status|reset}"
  echo "  status  Show the plugin's version and active settings"
  echo "  reset   Clear any pending subagent failure counters"
  exit 1
}

cmd_status() {
  echo "lolo-token-optimizer"
  if command -v jq >/dev/null 2>&1 && [[ -f "$MANIFEST" ]]; then
    jq -r '"version: " + .version, "defaultEffort: " + (.settings.defaultEffort // "n/a"), "maxFileTokenLimit: " + ((.settings.maxFileTokenLimit // "n/a") | tostring), "maxToolRetriesBeforeAbort: " + ((.settings.maxToolRetriesBeforeAbort // "n/a") | tostring)' "$MANIFEST"
  else
    echo "(jq unavailable or manifest not found: $MANIFEST)"
  fi
  echo "state directory: $STATE_DIR"
  if [[ -d "$STATE_DIR" ]]; then
    find "$STATE_DIR" -name 'failures-*.count' -exec echo "  active counter: {}" \; 2>/dev/null
  fi
}

cmd_reset() {
  rm -f "$STATE_DIR"/failures-*.count 2>/dev/null || true
  echo "Failure counters reset."
}

case "${1:-}" in
  status) cmd_status ;;
  reset) cmd_reset ;;
  *) usage ;;
esac
