#!/bin/bash
# PreToolUse / matcher "Read"
# Blocks raw reads of oversized files and suggests a targeted extraction
# (grep/sed/awk) instead.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

file_path=$(json_nested_field '.tool_input.file_path')
[[ -z "$file_path" ]] && exit 0
[[ -f "$file_path" ]] || exit 0

max_tokens=$(read_setting "maxFileTokenLimit" "10000")
# Rough approximation: ~4 bytes per token for typical text/code.
max_bytes=$(( max_tokens * 4 ))

size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo 0)

if (( size > max_bytes )); then
  approx_tokens=$(( size / 4 ))
  deny_tool "File too large (~${approx_tokens} estimated tokens, limit ${max_tokens}). Use grep/sed/awk or a ranged read (offset/limit) instead of loading the whole file."
fi

exit 0
