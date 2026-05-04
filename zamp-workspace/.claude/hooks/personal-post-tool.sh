#!/bin/bash
# Personal PostToolUse hook:
#  H1: run `ruff check --fix && ruff format` on *.py inside pantheon after edits
#  H4: run `gitleaks protect --staged` after edits to env-shaped files (best-effort)
# Output is informational; never blocks.

set -euo pipefail
input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$path" ] || exit 0
[ -f "$path" ] || exit 0

# H1: ruff for pantheon python files
if echo "$path" | grep -qE '/services/pantheon/.*\.py$'; then
    if command -v ruff >/dev/null 2>&1; then
        # Run from pantheon root so config is picked up
        repo_root="${path%%/services/pantheon/*}/services/pantheon"
        if [ -d "$repo_root" ]; then
            ( cd "$repo_root" && ruff check --fix --quiet "$path" 2>&1 | head -20 ; ruff format --quiet "$path" 2>&1 | head -5 ) >&2 || true
        fi
    fi
fi

# H4: gitleaks for env-shaped files
if echo "$path" | grep -qE '\.env(\..*)?$|/auth\.env$'; then
    if command -v gitleaks >/dev/null 2>&1; then
        # Scan just this file
        gitleaks protect --no-banner --redact --source "$path" 2>&1 | head -30 >&2 || true
    fi
fi

exit 0
