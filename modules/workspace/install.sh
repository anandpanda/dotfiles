#!/usr/bin/env bash
# Create the two project roots that git identity switching keys on.
set -euo pipefail
for d in "$HOME/work" "$HOME/personal"; do
  if [ -d "$d" ]; then
    echo "skip $d"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] mkdir $d"
  else
    mkdir -p "$d" && echo "mkdir $d"
  fi
done
