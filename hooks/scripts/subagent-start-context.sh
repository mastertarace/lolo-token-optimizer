#!/bin/bash
# SubagentStart
# Injects compression rules directly into the context of the subagent that
# is starting (useful when it's a lightweight model such as Haiku).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

inject_context "SubagentStart" "Token Optimizer constraint: answer compactly. No preamble, no trailing recap. Cite only useful results (path:line). If a task fails twice in a row the same way, stop and report the error as-is instead of retrying."
