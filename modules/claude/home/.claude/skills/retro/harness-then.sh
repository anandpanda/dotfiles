#!/usr/bin/env bash
# Rebuild the harness linked into ~/.claude as it was at a time: each repo the links point into, at its last commit before then.
# Writes <out>/.claude/... and prints which commit each repo was taken at, and the harness files no repo versions.
set -euo pipefail

at="$1"
out="$2"
mkdir -p "$out/.claude"

find "$HOME/.claude" -maxdepth 3 -type l | while read -r link; do
  target="$(readlink "$link")"
  case "$target" in */home/.claude/*) ;; *) continue ;; esac
  repo="$(git -C "$(dirname "$target")" rev-parse --show-toplevel)"
  module="${target%%/home/.claude/*}/home/.claude"
  echo "$repo|${module#"$repo"/}"
done | sort -u | while IFS='|' read -r repo module; do
  commit="$(git -C "$repo" rev-list -1 --before="$at" HEAD)"
  if [ -z "$commit" ]; then
    echo "$repo has no commit before $at"
    continue
  fi
  staging="$(mktemp -d)"
  git -C "$repo" archive "$commit" "$module" | tar -x -C "$staging"
  cp -R "$staging/$module/." "$out/.claude/"
  rm -rf "$staging"
  echo "$repo at $(git -C "$repo" rev-parse --short "$commit") ($(git -C "$repo" log -1 --format=%ci "$commit"))"
done

for file in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json"; do
  if [ -f "$file" ] && [ ! -L "$file" ]; then echo "not versioned: $file"; fi
done
