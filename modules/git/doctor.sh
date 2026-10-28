#!/usr/bin/env bash
# Signing keys exist for each identity; allowed_signers is current; hooks dir linked.
set -euo pipefail
cfg="$HOME/.config/git"
rc=0
for id in "$cfg"/identity.*; do
  [ -f "$id" ] || continue
  key="$(git config --file "$id" user.signingkey || true)"
  key="${key/#\~/$HOME}"
  [ -n "$key" ] || continue
  [ -f "$key" ] || {
    echo "signing key missing for $(basename "$id"): $key"
    rc=1
  }
done
[ -e "$cfg/hooks/commit-msg" ] || {
  echo "missing hooks/commit-msg"
  rc=1
}
if [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/git/allowed_signers" ]; then
  if ! DRY_RUN=1 bash "$DOTFILES_DIR/modules/git/install.sh" 2>/dev/null | grep -q '^skip '; then
    echo "allowed_signers is stale: rerun install"
    rc=1
  fi
fi
exit $rc
