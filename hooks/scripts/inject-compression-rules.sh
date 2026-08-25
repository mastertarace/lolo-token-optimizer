#!/bin/bash
# InstructionsLoaded
# Reminds the model of compression rules before delegating to a subagent.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

effort=$(read_setting "defaultEffort" "low")

inject_context "InstructionsLoaded" "Token Optimizer active (default effort: ${effort}). Before delegating to a subagent: Mission <= 15 words, Context provided <= 120 tokens. Prefer a lightweight model (e.g. Haiku) for simple search/read tasks."
