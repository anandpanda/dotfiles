#!/bin/bash
# F2b — PostToolUse on Edit|Write|MultiEdit: warn when hedge words appear in
# code comments / markdown / docstrings being written. Catches hedges that
# would otherwise rot in the codebase.

set -euo pipefail
input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$path" ] || exit 0

# Only scan text-y files
case "$path" in
  *.md|*.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.java|*.rb|*.sh|*.yml|*.yaml) ;;
  *) exit 0 ;;
esac

# Capture new content depending on tool shape
content=""
if [ "$tool" = "Write" ]; then
  content=$(echo "$input" | jq -r '.tool_input.content // empty')
elif [ "$tool" = "Edit" ]; then
  content=$(echo "$input" | jq -r '.tool_input.new_string // empty')
elif [ "$tool" = "MultiEdit" ]; then
  content=$(echo "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')
fi
[ -n "$content" ] || exit 0

hedge_re='(^|[^A-Za-z])(most likely|probably|possibly|presumably|should work|should be fine|i think|i believe|i assume|i'\''d guess|appears to|seems to)([^A-Za-z]|$)'

if echo "$content" | grep -iqE "$hedge_re"; then
  matches=$(echo "$content" | grep -inE "$hedge_re" | head -5)
  cat >&2 <<EOF
[factual-mode] Hedge word(s) detected in $path:
$matches

Rewrite each as either:
  - A factual statement with citation (path:line, doc URL, command output), or
  - "I don't know — verifying" followed by an actual verification step, or
  - Just delete the hedge and state the fact directly.

If the hedge is in quoted user content, that's fine.
EOF
fi

exit 0
