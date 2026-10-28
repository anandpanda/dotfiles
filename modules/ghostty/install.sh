#!/usr/bin/env bash
# Linux: Ghostty is in apt on Ubuntu 26.04+, else the Snap (built by Ghostty's own CI).
set -euo pipefail
for f in log os; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
[ "$(os_name)" = linux ] || exit 0
if command -v ghostty >/dev/null 2>&1; then
  echo "skip ghostty"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] install ghostty (apt or snap)"
  exit 0
fi
if command -v apt-get >/dev/null 2>&1 && apt-cache policy ghostty 2>/dev/null | grep -q '^ghostty:'; then
  sudo apt-get install -y -qq ghostty >/dev/null && echo "installed ghostty (apt)" && exit 0
fi
if command -v snap >/dev/null 2>&1; then
  sudo snap install ghostty --classic >/dev/null && echo "installed ghostty (snap)" && exit 0
fi
log_warn "ghostty: no apt package or snap here; see https://ghostty.org/docs/install/binary"
