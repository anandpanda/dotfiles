#!/bin/bash
# SessionStart hook: inject git context into Claude's awareness.
# - If cwd is itself a git repo: show that repo's state
# - Else: discover every git repo in workspace (depth 2-3) and show all

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && exit 0
WORKSPACE="${ZAMP_WORKSPACE:-$HOME/zamp}"

repo_summary() {
    local path="$1"
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || return
    local b=$(git -C "$path" branch --show-current 2>/dev/null)
    [ -z "$b" ] && b="<detached>"
    local changed=$(git -C "$path" diff --name-only HEAD 2>/dev/null | wc -l)
    local untracked=$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null | wc -l)
    local last=$(git -C "$path" log -1 --format='%s' 2>/dev/null | cut -c1-60)
    echo "$(basename "$path"): branch=$b changed=$changed untracked=$untracked | last=\"$last\""
}

context=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    context=$(repo_summary "$cwd")
else
    lines=()
    while IFS= read -r gitdir; do
        repo=$(dirname "$gitdir")
        s=$(repo_summary "$repo")
        [ -n "$s" ] && lines+=("$s")
    done < <(find "$WORKSPACE" -mindepth 2 -maxdepth 3 -name ".git" -type d 2>/dev/null | sort)

    if [ ${#lines[@]} -gt 0 ]; then
        context=$(printf 'Repos in workspace:\n%s' "$(printf '  - %s\n' "${lines[@]}")")
    fi
fi

[ -z "$context" ] && exit 0

jq -n --arg c "$context" '{
    hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $c
    }
}'
