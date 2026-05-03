#!/bin/bash
# Stop hook: append rich journal entry per turn end IFF state has changed.
# - If cwd is itself a git repo: log only that repo's state
# - Else: discover every git repo in workspace (depth 2-3) and log all
# - Skip the write when content is identical to the previous entry (dedup)
# Runs async, won't block Claude.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
session=$(echo "$input" | jq -r '.session_id // "?"' | cut -c1-8)
ts=$(date '+%Y-%m-%d %H:%M:%S')
journal="$HOME/.claude/journal.log"
WORKSPACE="${ZAMP_WORKSPACE:-$HOME/zamp}"

repo_line() {
    local path="$1"
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || return

    local branch=$(git -C "$path" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch="<detached>"

    local changed=$(git -C "$path" diff --name-only HEAD 2>/dev/null | wc -l)
    local untracked=$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null | wc -l)

    local status_part="clean"
    if [ "$changed" -gt 0 ] || [ "$untracked" -gt 0 ]; then
        status_part=""
        [ "$changed" -gt 0 ] && status_part="${changed}c"
        if [ "$untracked" -gt 0 ]; then
            [ -n "$status_part" ] && status_part="$status_part,"
            status_part="${status_part}${untracked}u"
        fi
    fi

    local last=$(git -C "$path" log -1 --format='%s' 2>/dev/null | cut -c1-60)

    local pr=""
    if command -v gh >/dev/null 2>&1 && [ "$branch" != "<detached>" ]; then
        local pr_num=$(cd "$path" && gh pr list --head "$branch" --json number --jq '.[0].number // empty' 2>/dev/null)
        [ -n "$pr_num" ] && pr=" PR#$pr_num"
    fi

    echo "  $(basename "$path"): $branch | $status_part | \"$last\"$pr"
}

# Build the body (everything except the timestamp header)
build_body() {
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        repo_line "$cwd"
    else
        while IFS= read -r gitdir; do
            repo_line "$(dirname "$gitdir")"
        done < <(find "$WORKSPACE" -mindepth 2 -maxdepth 3 -name ".git" -type d 2>/dev/null | sort)
    fi
}

new_body=$(build_body)
[ -z "$new_body" ] && exit 0

# Compare against last entry's body — skip if identical (dedup)
if [ -f "$journal" ]; then
    last_header_line=$(grep -nE '^\[20[0-9]{2}-' "$journal" 2>/dev/null | tail -1 | cut -d: -f1)
    if [ -n "$last_header_line" ]; then
        last_body=$(tail -n +$((last_header_line + 1)) "$journal")
        if [ "$new_body" = "$last_body" ]; then
            exit 0
        fi
    fi
fi

# Different from last → append
{
    echo "[$ts] sess=$session"
    echo "$new_body"
} >> "$journal"

exit 0
