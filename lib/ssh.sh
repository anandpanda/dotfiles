#!/usr/bin/env bash
# Guided SSH key setup. Asks only when a key is missing and a terminal is attached.

ssh_key_path() { echo "$HOME/.ssh/id_ed25519_$1"; }

ssh_contexts_for_profile() {
  echo personal
  profile_has_overlay "$1" 2>/dev/null && echo work
  return 0
}

ssh_test() {
  local out
  out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T "git@github.com-$1" 2>&1 || true)"
  case "$out" in *"successfully authenticated"*) return 0 ;; *) return 1 ;; esac
}

ssh_ensure_key() {
  local ctx="$1" email="$2" key ans
  key="$(ssh_key_path "$ctx")"
  if [ -f "$key" ]; then
    log_ok "ssh key $ctx present"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "generate ssh key $key"
    return 0
  elif ! is_tty; then
    log_warn "no terminal: skipping ssh key generation for $ctx"
    return 0
  else
    printf 'Generate %s ssh key at %s? [Y/n] ' "$ctx" "$key"
    read -r ans
    case "$ans" in n | N)
      log_warn "skipped $ctx key"
      return 0
      ;;
    esac
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
    echo
    echo "Add this public key at https://github.com/settings/keys :"
    echo
    cat "$key.pub"
    echo
    printf 'Press enter once added... '
    read -r _
  fi
  if [ "${DRY_RUN:-0}" != 1 ]; then
    if ssh_test "$ctx"; then log_ok "github.com-$ctx authenticates"; else log_warn "github.com-$ctx does not authenticate yet"; fi
  fi
}
