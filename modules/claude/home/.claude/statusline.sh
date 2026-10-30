#!/usr/bin/env bash
# Claude Code status line: model, context percent, repo and branch with * when dirty.
IFS=$'\037' read -r model pct cwd < <(jq -r '[.model.display_name // "?", (.context_window.used_percentage // 0 | floor), .workspace.current_dir // .cwd // ""] | map(tostring) | join("\u001f")')
out="$model · ${pct}%"
if [ -n "$cwd" ] && top="$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)"; then
  branch="$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)"
  mark=""
  [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -c 1)" ] && mark="*"
  out="$out · ${top##*/} ${branch}${mark}"
fi
printf '%s\n' "$out"
