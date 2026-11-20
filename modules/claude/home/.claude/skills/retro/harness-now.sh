#!/usr/bin/env bash
# Copy today's harness from ~/.claude into <out>/.claude as real files: search tools skip the symlinks ~/.claude is made of.
set -euo pipefail

out="$1"
mkdir -p "$out/.claude"
for part in rules skills agents review CLAUDE.md settings.json; do
  if [ -e "$HOME/.claude/$part" ]; then cp -RL "$HOME/.claude/$part" "$out/.claude/"; fi
done
