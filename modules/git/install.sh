#!/usr/bin/env bash
# Generate ~/.local/state/git/allowed_signers from the identities and keys on this machine,
# so `git log --show-signature` verifies locally. One line per identity whose key exists.
# Also writes the context folder lists, the includeIf file that picks the identity, and
# the machine's ~/.gitconfig whose first line includes the repo config.
set -euo pipefail
for f in log os link profile module contexts file git; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
cfg="$HOME/.config/git"
# The commit-msg hook ships in config/template/hooks; git's init.templateDir copies it into
# every new or cloned repo (git ignores a template whose hooks dir is a symlink).
# Generated signers live in state, never in the (linked) config dir.
out="$HOME/.local/state/git/allowed_signers" # matches gpg.ssh.allowedSignersFile in base.gitconfig
gitconfig_ensure_include

contexts="$(contexts_collect)" || die "cannot collect context folders"
contexts_write "$contexts" || exit 1

# Each identity signs with whatever key is effective in its folders (a template may
# append its own), so the signer line comes from a probe there, not the identity file.
want=""
for ctx in personal work; do
  folder="$(printf '%s\n' "$contexts" | contexts_first_folder "$ctx")" || continue
  email="$(git_in_folder "$folder" config user.email || true)"
  key="$(git_signing_key_in "$folder")"
  if [ -z "$email" ] || [ -z "$key" ] || [ ! -f "$key" ]; then continue; fi
  want="${want}${email} namespaces=\"git\" $(git_public_key "$key")"$'\n'
done
put_file "$out" "${want%$'\n'}"

# Existing repos under the context folders predate the template: give them the hook
# unless they already have one of their own (never overwrite a repo's hook).
hook="$cfg/template/hooks/commit-msg"
while IFS= read -r root; do
  if [ -z "$root" ] || [ ! -d "$root" ]; then continue; fi
  while IFS= read -r gitdir; do
    dst="$gitdir/hooks/commit-msg"
    [ -e "$dst" ] && continue
    if [ "${DRY_RUN:-0}" = 1 ]; then
      echo "[dry] hook -> $dst"
    else
      mkdir -p "$gitdir/hooks" && cp "$hook" "$dst" && chmod +x "$dst" && echo "hook -> $dst"
    fi
  done < <(find "$root" -maxdepth 4 -type d -name .git -not -path '*/node_modules/*' 2>/dev/null)
done < <(printf '%s\n' "$contexts" | cut -f2)
