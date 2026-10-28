#!/usr/bin/env bash
set -euo pipefail
for f in log profile ssh; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
profile="$(recall profile 2>/dev/null || echo "${DOTFILES_PROFILE:-personal}")"
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
for ctx in $(ssh_contexts_for_profile "$profile"); do
  email="${DOTFILES_EMAIL_PERSONAL:-}"
  [ "$ctx" = work ] && email="${DOTFILES_EMAIL_WORK:-}"
  ssh_ensure_key "$ctx" "${email:-$ctx@$(hostname -s)}"
done
