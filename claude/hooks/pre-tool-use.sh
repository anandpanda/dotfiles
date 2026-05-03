#!/bin/bash
# PreToolUse hook: prompts user before destructive ops or sensitive file access.
# Returns permissionDecision: "ask" so user gets a confirmation prompt
# with a custom warning message instead of silent allow or hard block.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

ask() {
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

if [ "$tool" = "Bash" ]; then
    cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

    if echo "$cmd" | grep -qE '\bgit\s+push\b.*(--force\b|-f\b|--force-with-lease\b)'; then
        ask "FORCE PUSH detected. Rewrites remote history. Command: $cmd"
    fi

    if echo "$cmd" | grep -qE '\bgit\s+reset\s+--hard\b'; then
        ask "git reset --hard discards uncommitted changes and moves HEAD. Command: $cmd"
    fi

    if echo "$cmd" | grep -qE '\brm\s+-[a-zA-Z]*[rR][a-zA-Z]*[fF]|\brm\s+-[a-zA-Z]*[fF][a-zA-Z]*[rR]|\brm\s+--recursive.*--force|\brm\s+--force.*--recursive'; then
        ask "Recursive force delete: $cmd"
    fi

    if echo "$cmd" | grep -qE '\bgit\s+clean\s+-[a-zA-Z]*f[a-zA-Z]*d|\bgit\s+clean\s+-[a-zA-Z]*d[a-zA-Z]*f'; then
        ask "git clean -fd deletes untracked files. Command: $cmd"
    fi
fi

if [ "$tool" = "Read" ] || [ "$tool" = "Edit" ] || [ "$tool" = "Write" ] || [ "$tool" = "MultiEdit" ]; then
    path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')

    if echo "$path" | grep -qE '(^|/)\.env(\.|$)|\.env$'; then
        ask "Sensitive file: $path. .env files commonly hold secrets."
    fi

    if echo "$path" | grep -qE '(^|/)secrets\.|(^|/)credentials\.'; then
        ask "Sensitive file: $path. Looks like secrets/credentials."
    fi

    if echo "$path" | grep -qE '(^|/)\.git/'; then
        ask "Direct .git/ access: $path. Prefer git commands."
    fi
fi

exit 0
