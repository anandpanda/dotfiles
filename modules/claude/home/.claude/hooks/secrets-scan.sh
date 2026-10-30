#!/usr/bin/env bash
# Warns when Bash output looks like a token; never blocks.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

hook_input
out="$(hook_field '.tool_response | if type == "object" then "\(.stdout // "")\n\(.stderr // "")" else tostring end')"
if hook_has_token <<<"$out"; then
  hook_context PostToolUse "That output looks like a token. Do not repeat, store or summarise it; tell the user it was exposed so they can rotate it, and use \`with-secrets <cmd>\` next time."
fi
exit 0
