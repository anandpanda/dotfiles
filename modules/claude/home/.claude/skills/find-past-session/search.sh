#!/usr/bin/env bash
# Search past Claude Code transcripts for any of the given phrases and print session, date and the matching text.
set -eu

[ "$#" -gt 0 ] || {
  echo "usage: search.sh <phrase>..." >&2
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
    printf '%s\n' "${hit#*.jsonl:}" |
      jq -r '
        def flat: if type == "string" then .
          elif type == "array" then map(if type == "object" then (.text // .content // .input // "") | flat else tostring end) | join(" ")
          else tostring end;
        select(.type == "user" or .type == "assistant")
        | [(.timestamp // "")[0:10], (.message.content | flat | gsub("\\s+"; " "))] | @tsv
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
