#!/bin/bash
# Installs lolo-token-optimizer into the user's Claude Code plugins directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/plugins/lolo-token-optimizer"

if [[ ! -f "$SCRIPT_DIR/.claude-plugin/plugin.json" ]]; then
  echo "Error: .claude-plugin/plugin.json not found in $SCRIPT_DIR. Run this script from the plugin's source directory." >&2
  exit 1
fi

if [[ -d "$TARGET_DIR" ]]; then
  read -r -p "Target $TARGET_DIR already exists. Overwrite? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"
cp -r "$SCRIPT_DIR"/. "$TARGET_DIR"/
chmod +x "$TARGET_DIR"/cli.sh "$TARGET_DIR"/hooks/scripts/*.sh

echo "Installed to $TARGET_DIR"
echo "Enable it in Claude Code: /plugin install lolo-token-optimizer (or restart Claude Code if plugins auto-load from ~/.claude/plugins)."
