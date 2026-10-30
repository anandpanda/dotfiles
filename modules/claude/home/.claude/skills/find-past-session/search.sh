#!/usr/bin/env bash
# Search past Claude Code transcripts for any of the given phrases and print session, date and the matching text.
set -eu

exclude=""
if [ "${1:-}" = --exclude ]; then
  exclude="$2"
  shift 2
fi
[ "$#" -gt 0 ] || {
  echo "usage: search.sh [--exclude <session>] <phrase>..." >&2
  exit 2
}

patterns=()
for phrase in "$@"; do patterns+=(-e "$phrase"); done
PHRASES="$(printf '%s\n' "$@")"
export PHRASES

{ grep -iF -H "${patterns[@]}" -- "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null || true; } |
  while IFS= read -r hit; do
    file="${hit%%.jsonl:*}.jsonl"
    session="$(basename "$file" .jsonl)"
    [ "$session" != "$exclude" ] || continue
    printf '%s\n' "${hit#*.jsonl:}" |
      jq -r '
        select(.type == "user" or .type == "assistant")
        | [
            (.timestamp // "")[0:10],
            (.message.content
              | if type == "string" then .
                else map(if .type == "text" then .text elif .type == "tool_use" then (.input.command // "") else "" end) | join(" ")
                end
              | gsub("\\s+"; " "))
          ]
        | @tsv
      ' |
      awk -F '\t' -v session="$session" '
        BEGIN { n = split(ENVIRON["PHRASES"], phrases, "\n") }
        {
          text = $2; lower = tolower(text); at = 0
          for (i = 1; i <= n; i++) {
            if (phrases[i] == "") continue
            p = index(lower, tolower(phrases[i]))
            if (p && (!at || p < at)) at = p
          }
          if (!at) next
          start = at > 60 ? at - 60 : 1
          printf "%s  %s  %s\n", session, $1, substr(text, start, 200)
        }
      '
  done | head -n 30
