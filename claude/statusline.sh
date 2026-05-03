#!/bin/bash
# Claude Code statusline
# Reads session JSON on stdin, prints one line to stdout.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
dir_display="${cwd/#$HOME/~}"

branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    b=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -n "$b" ] && branch=" │  $b"
fi

printf '\033[36m%s\033[0m │ \033[32m%s\033[0m\033[33m%s\033[0m' "$model" "$dir_display" "$branch"
