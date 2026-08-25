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

echo "Copied to $TARGET_DIR (kept for manual inspection / cli.sh use)."
echo
echo "This copy alone does NOT activate the plugin. Claude Code loads plugins"
echo "through a marketplace registration. Run inside a Claude Code session:"
echo
echo "  /plugin marketplace add $SCRIPT_DIR"
echo "  /plugin install lolo-token-optimizer"
echo
echo "(Or, for the published repo: /plugin marketplace add mastertarace/lolo-token-optimizer)"
echo "For quick local testing without registering a marketplace, you can also run:"
echo "  claude --plugin-dir $SCRIPT_DIR"
