#!/usr/bin/env bash
# Print one session's conversation as JSON lines {role, ts, text}: Anand's prompts and Claude's text, no tool traffic.
# Takes a transcript path, a session id (a resumed session can exist in several project folders, so the newest copy wins), or nothing for the cwd's newest session.
set -euo pipefail

newest_transcript() {
  local dir f newest=""
  dir="$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
  for f in "$dir"/*.jsonl; do
    [ -e "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  [ -n "$newest" ] || {
    echo "no transcript for $(pwd) in $dir" >&2
    return 1
  }
  echo "$newest"
}

newest_by_id() {
  local f newest=""
  for f in "$HOME"/.claude/projects/*/"$1".jsonl; do
    [ -e "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  [ -n "$newest" ] || {
    echo "no transcript for session $1" >&2
    return 1
  }
  echo "$newest"
}

case "${1:-}" in
  "") transcript="$(newest_transcript)" ;;
  */* | *.jsonl) transcript="$1" ;;
  *) transcript="$(newest_by_id "$1")" ;;
esac

jq -c '
  select(.type == "user" or .type == "assistant")
  | select((.isSidechain // false) == false and (.isMeta // false) == false and (.isCompactSummary // false) == false)
  | {role: .message.role, ts: .timestamp, text: (
      .message.content
      | if type == "string" then . else map(select(.type == "text") | .text) | join("\n") end
    )}
  | select(.text != "" and (.text | startswith("<task-notification>") | not))
' "$transcript"
