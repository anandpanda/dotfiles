#!/usr/bin/env bash
# Generate missing ssh keys and verify GitHub access. Asks only when a key is missing.
set -euo pipefail
for f in log profile ssh; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
profile="${DOTFILES_PROFILE:-$(profile_default)}"
for ctx in $(profile_identities "$profile"); do
  email="${DOTFILES_EMAIL_PERSONAL:-}"
  [ "$ctx" = work ] && email="${DOTFILES_EMAIL_WORK:-}"
  ssh_ensure_key "$ctx" "${email:-$ctx@$(hostname -s)}"
done
