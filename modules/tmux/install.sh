#!/usr/bin/env bash
# Install tpm at a pinned tag. Plugins themselves are pinned in tmux.conf (#vX.Y.Z).
set -euo pipefail
dir="$HOME/.config/tmux/plugins/tpm"
tag=v3.1.0
repo="${TPM_REPO:-https://github.com/tmux-plugins/tpm.git}"
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] ensure tpm $tag at $dir"
  exit 0
fi
if [ ! -d "$dir/.git" ]; then
  git -c advice.detachedHead=false clone -q --branch "$tag" "$repo" "$dir"
  echo "installed tpm $tag"
elif git -C "$dir" tag --points-at HEAD 2>/dev/null | grep -qx "$tag"; then
  echo "skip tpm $tag"
else
  git -C "$dir" fetch -q --tags && git -C "$dir" checkout -q "$tag" && echo "moved tpm to $tag"
fi

# tpm never moves an already-installed plugin, so enforce each pinned tag here.
conf="$HOME/.config/tmux/tmux.conf"
[ -f "$conf" ] || exit 0
grep -E "^set -g @plugin '[^']+#v" "$conf" | sed -E "s/.*@plugin '([^#']+)#([^']+)'.*/\1 \2/" |
  while read -r plugin ptag; do
    pdir="$HOME/.config/tmux/plugins/${plugin##*/}"
    [ -d "$pdir/.git" ] || continue
    if ! git -C "$pdir" tag --points-at HEAD 2>/dev/null | grep -qx "$ptag"; then
      git -C "$pdir" fetch -q --tags && git -C "$pdir" -c advice.detachedHead=false checkout -q "$ptag" && echo "moved ${plugin##*/} to $ptag"
    fi
  done
