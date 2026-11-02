#!/usr/bin/env bash
# Guided SSH key setup. Asks only when a key is missing and a terminal is attached.

ssh_key_path() { echo "$HOME/.ssh/id_ed25519_$1"; }
ssh_github_conf() { echo "$DOTFILES_DIR/modules/ssh/home/.ssh/conf.d/github.conf"; }

# Key files the github.com-CTX alias offers, in order, read by ssh itself from the repo's config.
ssh_key_candidates() {
  ssh -G -F "$(ssh_github_conf)" "github.com-$1" </dev/null 2>/dev/null | sed -n "s|^identityfile ~/|$HOME/|p"
}

# The first candidate key file that exists.
ssh_key_found() {
  local k
  while IFS= read -r k; do
    if [ -f "$k" ]; then
      echo "$k"
      return 0
    fi
  done < <(ssh_key_candidates "$1")
  return 1
}

ssh_test() { # KEY_FILE
  local out
  # Use the key directly: the host alias is only linked in the configure step, after preflight.
  out="$(ssh -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  case "$out" in *"successfully authenticated"*) return 0 ;; *) return 1 ;; esac
}

# Generate KEY for CTX after asking. Fails when nothing was generated.
_ssh_generate_key() { # CTX EMAIL KEY
  local ctx="$1" email="$2" key="$3" ans
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "generate ssh key $key"
    return 1
  fi
  if ! is_tty; then
    log_warn "no terminal: skipping ssh key generation for $ctx"
    return 1
  fi
  ask "Generate $ctx ssh key at $key? [Y/n] " ans
  case "$ans" in n | N)
    log_warn "skipped $ctx key"
    return 1
    ;;
  esac
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
  echo
  echo "Add this public key at https://github.com/settings/keys :"
  echo
  cat "$key.pub"
  echo
  ask 'Press enter once added... ' _
}

# A key for CTX exists when any of its alias's candidate files does; only then is nothing generated.
ssh_ensure_key() { # CTX EMAIL
  local ctx="$1" email="$2" key
  if key="$(ssh_key_found "$ctx")"; then
    log_ok "ssh key $ctx present: $key"
  else
    key="$(ssh_key_path "$ctx")"
    _ssh_generate_key "$ctx" "$email" "$key" || return 0
  fi
  [ "${DRY_RUN:-0}" != 1 ] || return 0
  if ssh_test "$key"; then log_ok "github.com-$ctx authenticates"; else log_warn "github.com-$ctx does not authenticate yet"; fi
}

# Make ~/.ssh/config start with an Include of ~/.ssh/conf.d/*.conf. Never replaces the
# file: other tools (Coder, VS Code Remote) write into it. An Include applies to every
# host only above the first Host block, so it is the first line.
ssh_ensure_include() {
  local cfg="$HOME/.ssh/config"
  if [ "${DRY_RUN:-0}" != 1 ]; then mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; fi
  file_ensure_first_line "$cfg" 'Include ~/.ssh/conf.d/*.conf'
  if [ "${DRY_RUN:-0}" != 1 ]; then chmod 600 "$cfg"; fi
}
