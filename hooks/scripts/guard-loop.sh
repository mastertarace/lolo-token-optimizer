#!/bin/bash
# PreToolUse / matcher "*"
# Cuts off a subagent that has chained too many consecutive failures on the
# same tool (looping), before even attempting the next call.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

max_retries=$(read_setting "maxToolRetriesBeforeAbort" "2")
counter_file=$(failure_counter_file)

count=0
[[ -f "$counter_file" ]] && count=$(cat "$counter_file" 2>/dev/null || echo 0)

if (( count >= max_retries )); then
  rm -f "$counter_file" 2>/dev/null
  deny_tool "Error loop detected (${count} consecutive failures, limit ${max_retries}). Task handed back: stop this approach and report a condensed error to the main model instead of retrying."
fi

exit 0
