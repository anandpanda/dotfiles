#!/usr/bin/env bash
# Generate ~/.config/git/allowed_signers from the identities and keys on this machine,
# so `git log --show-signature` verifies locally. One line per identity whose key exists.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
cfg="$HOME/.config/git"
out="$cfg/allowed_signers"
want=""
for id in "$cfg"/identity.*; do
  [ -f "$id" ] || continue
  email="$(git config --file "$id" user.email || true)"
  key="$(git config --file "$id" user.signingkey || true)"
  key="${key/#\~/$HOME}"
  [ -n "$email" ] && [ -n "$key" ] && [ -f "$key" ] || continue
  want="${want}${email} namespaces=\"git\" $(cut -d' ' -f1,2 "$key")"$'\n'
done
if [ -f "$out" ] && [ "$(cat "$out")" = "${want%$'\n'}" ]; then
  echo "skip $out"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] write $out ($(printf '%s' "$want" | grep -c .) signer(s))"
  exit 0
fi
mkdir -p "$cfg"
printf '%s' "$want" >"$out.tmp" && mv "$out.tmp" "$out"
echo "wrote $out ($(grep -c . "$out") signer(s))"
