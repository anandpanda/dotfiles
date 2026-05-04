#!/bin/bash
# Personal PreToolUse extensions (complement to dotfiles pre-tool-use.sh):
#  H8 extras: auth.env, .temporal-cert, .temporal-key, .security-waivers.json
#  H9: block edits to poetry.lock
#  H10: block edits to *_pb2.py / *_pb2_grpc.py (generated stubs)
#  H14: block `from temporalio` and relative imports inside pantheon
# Returns permissionDecision: "ask" or "deny" with a custom reason.

set -euo pipefail
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

deny() {
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

if [ "$tool" = "Edit" ] || [ "$tool" = "Write" ] || [ "$tool" = "MultiEdit" ]; then
    path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

    # H8 extras
    if echo "$path" | grep -qE '(^|/)auth\.env$|(^|/)\.temporal-cert$|(^|/)\.temporal-key$|(^|/)\.security-waivers\.json$'; then
        ask "Sensitive file: $path. Confirm before modifying."
    fi

    # H9: poetry.lock — direct edits corrupt the lockfile
    if echo "$path" | grep -qE '(^|/)poetry\.lock$'; then
        deny "Refusing to edit poetry.lock directly. Run \`poetry lock\` (or \`poetry add\`/\`poetry update\`) instead."
    fi

    # H10: generated protobuf stubs
    if echo "$path" | grep -qE '_pb2(_grpc)?\.py$'; then
        deny "Refusing to edit generated protobuf stub: $path. Edit the source .proto file and regenerate."
    fi

    # H14: pantheon architectural rules — only when target file is inside pantheon
    if echo "$path" | grep -qE '/services/pantheon/.*\.py$'; then
        # Inspect new content
        new_content=""
        if [ "$tool" = "Write" ]; then
            new_content=$(echo "$input" | jq -r '.tool_input.content // empty')
        elif [ "$tool" = "Edit" ]; then
            new_content=$(echo "$input" | jq -r '.tool_input.new_string // empty')
        elif [ "$tool" = "MultiEdit" ]; then
            new_content=$(echo "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')
        fi

        if [ -n "$new_content" ]; then
            # Direct temporalio import — must go through ActionsHub
            if echo "$new_content" | grep -qE '^\s*(from\s+temporalio|import\s+temporalio)\b'; then
                ask "ActionsHub rule: this file imports temporalio directly. ActionsHub.execute_activity()/execute_workflow() should be used instead. Confirm if intentional (e.g. inside ActionsHub itself)."
            fi
            # Relative imports
            if echo "$new_content" | grep -qE '^\s*from\s+\.\.?(\s+import|[a-zA-Z_])'; then
                ask "Pantheon rule: relative imports are forbidden — use absolute imports (from pantheon_v2....). Confirm if intentional."
            fi
        fi
    fi
fi

exit 0
