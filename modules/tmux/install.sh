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
  git clone -q --branch "$tag" "$repo" "$dir"
  echo "installed tpm $tag"
  exit 0
fi
if [ "$(git -C "$dir" describe --tags --exact-match 2>/dev/null)" = "$tag" ]; then
  echo "skip tpm $tag"
else
  git -C "$dir" fetch -q --tags && git -C "$dir" checkout -q "$tag" && echo "moved tpm to $tag"
fi
