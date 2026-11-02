#!/usr/bin/env bash
# Machine files that other tools also write keep their content; ours is only their first line.

# Makes LINE the first line of FILE and keeps the rest; a symlinked FILE is edited at its target.
file_ensure_first_line() { # FILE LINE
  local file="$1" line="$2" real="$1" tmp
  [ ! -L "$file" ] || real="$(readlink "$file")"
  if [ -f "$real" ] && [ "$(head -1 "$real")" = "$line" ]; then
    echo "skip $file"
    return 0
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "write $file"
    return 0
  fi
  mkdir -p "$(dirname "$real")"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$line"
    [ ! -f "$real" ] || cat "$real"
  } >"$tmp"
  cat "$tmp" >"$real" && rm -f "$tmp"
  echo "wrote $file"
}
