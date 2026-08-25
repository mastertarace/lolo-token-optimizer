#!/bin/bash
# PostToolUse (success) / SubagentStop / Stop
# Clears the consecutive-failure counter once a tool succeeds, or cleans up
# state when the session/subagent ends.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

counter_file=$(failure_counter_file)
rm -f "$counter_file" 2>/dev/null

exit 0
