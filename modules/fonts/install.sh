#!/usr/bin/env bash
# Linux: install JetBrains Mono Nerd Font into the user font dir. macOS uses the cask.
set -euo pipefail
[ "$(uname -s)" = Linux ] || exit 0
dir="$HOME/.local/share/fonts/JetBrainsMono"
if [ -d "$dir" ]; then
  echo "skip $dir"
else
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] download nerd font to $dir"
    exit 0
  fi
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/jb.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  mkdir -p "$tmp/out"
  if command -v unzip >/dev/null 2>&1; then
    unzip -qo "$tmp/jb.zip" -d "$tmp/out"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "$tmp/jb.zip" "$tmp/out"
  else
    echo "fonts: need unzip or python3 to extract" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dir")" && mv "$tmp/out" "$dir" && rm -rf "$tmp"
  echo "installed $dir"
fi
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$dir" >/dev/null
else
  echo "warn: fc-cache not found; install fontconfig so apps see the font"
fi
