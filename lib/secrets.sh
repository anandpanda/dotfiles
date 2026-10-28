#!/usr/bin/env bash
# ~/.secrets holds one file per secret. Never in any repo.

secrets_dir() { echo "$HOME/.secrets"; }
secrets_manifest() { echo "$DOTFILES_DIR/modules/secrets/manifest.txt"; }

# Prints "name  purpose" for every manifest entry without a file.
secrets_missing() {
  local name rest
  [ -f "$(secrets_manifest)" ] || return 0
  while read -r name rest; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    [ -f "$(secrets_dir)/$name" ] || printf '%s  %s\n' "$name" "$rest"
  done <"$(secrets_manifest)"
}
