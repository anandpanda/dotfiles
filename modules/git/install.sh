#!/usr/bin/env bash
# Generate ~/.local/state/git/allowed_signers from the identities and keys on this machine,
# so `git log --show-signature` verifies locally. One line per identity whose key exists.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
cfg="$HOME/.config/git"
# The commit-msg hook ships in config/template/hooks; git's init.templateDir copies it into
# every new or cloned repo (git ignores a template whose hooks dir is a symlink).
# Generated signers live in state, never in the (linked) config dir.
out="$HOME/.local/state/git/allowed_signers" # matches gpg.ssh.allowedSignersFile in .gitconfig
want=""
for id in "$cfg"/identity.*; do
  [ -f "$id" ] || continue
  email="$(git config --file "$id" user.email || true)"
  key="$(git config --file "$id" user.signingkey || true)"
  key="${key/#\~/$HOME}"
  if [ -z "$email" ] || [ -z "$key" ] || [ ! -f "$key" ]; then continue; fi
  want="${want}${email} namespaces=\"git\" $(cut -d' ' -f1,2 "$key")"$'\n'
done
if [ -f "$out" ] && [ "$(cat "$out")" = "${want%$'\n'}" ]; then
  echo "skip $out"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] write $out ($(printf '%s' "$want" | grep -c .) signer(s))"
else
  mkdir -p "$(dirname "$out")"
  printf '%s' "$want" >"$out.tmp" && mv "$out.tmp" "$out"
  echo "wrote $out ($(grep -c . "$out") signer(s))"
fi

# Existing repos under ~/work and ~/personal predate the template: give them the hook
# unless they already have one of their own (never overwrite a repo's hook).
hook="$cfg/template/hooks/commit-msg"
for root in "$HOME/work" "$HOME/personal"; do
  [ -d "$root" ] || continue
  while IFS= read -r gitdir; do
    dst="$gitdir/hooks/commit-msg"
    [ -e "$dst" ] && continue
    if [ "${DRY_RUN:-0}" = 1 ]; then
      echo "[dry] hook -> $dst"
    else
      mkdir -p "$gitdir/hooks" && cp "$hook" "$dst" && chmod +x "$dst" && echo "hook -> $dst"
    fi
  done < <(find "$root" -maxdepth 4 -type d -name .git -not -path '*/node_modules/*' 2>/dev/null)
done
