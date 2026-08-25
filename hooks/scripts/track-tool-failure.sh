#!/bin/bash
# PostToolUseFailure / matcher "*"
# Increments the consecutive-failure counter for the current session+agent.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

counter_file=$(failure_counter_file)
count=0
[[ -f "$counter_file" ]] && count=$(cat "$counter_file" 2>/dev/null || echo 0)
count=$(( count + 1 ))
echo "$count" > "$counter_file"

exit 0
