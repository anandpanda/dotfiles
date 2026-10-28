#!/usr/bin/env bash
# Every cask in Brewfile.macos is installed. Casks with auto_updates update themselves; that is fine.
set -euo pipefail
for f in log os brew; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
command -v brew >/dev/null 2>&1 || exit 0
installed="$(brew list --cask 2>/dev/null | sort -u)"
rc=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  grep -qxF "$c" <<<"$installed" || {
    echo "missing cask $c (dots install)"
    rc=1
  }
done < <(brew_names "$DOTFILES_DIR/modules/apps/Brewfile.macos")
exit $rc
