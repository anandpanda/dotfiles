#!/usr/bin/env bash
# ~/.secrets: one sops-encrypted file (secrets.yaml), the age key that opens it, the sops
# config that encrypts to that key. Never in any repo. Nothing here prints a value.

secrets_dir() { echo "$HOME/.secrets"; }
secrets_file() { echo "$(secrets_dir)/secrets.yaml"; }
secrets_age_key() { echo "$(secrets_dir)/age.key"; }
secrets_manifest() { echo "$DOTFILES_DIR/modules/secrets/manifest.txt"; }

# True when KEY exists in secrets.yaml. Decrypts in memory only; output discarded.
secrets_has() {
  [ -f "$(secrets_file)" ] || return 1
  command -v sops >/dev/null 2>&1 || return 1
  SOPS_AGE_KEY_FILE="$(secrets_age_key)" sops -d --extract "[\"$1\"]" "$(secrets_file)" >/dev/null 2>&1
}

# Prints "KEY  purpose" for every manifest key not in secrets.yaml.
secrets_missing() {
  local name rest
  [ -f "$(secrets_manifest)" ] || return 0
  while read -r name rest; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    secrets_has "$name" || printf '%s  %s\n' "$name" "$rest"
  done <"$(secrets_manifest)"
}
