load helper
setup() {
  setup_home
  for f in log profile ssh; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "key path per context" {
  [ "$(ssh_key_path work)" = "$HOME/.ssh/id_ed25519_work" ]
}

@test "identities per profile: server-work has no personal identity" {
  run profile_identities personal; [ "$output" = "personal" ]
  run profile_identities work; [ "$output" = $'personal\nwork' ]
  run profile_identities server; [ "$output" = "personal" ]
  run profile_identities server-work; [ "$output" = "work" ]
}

@test "existing key is reported present, no prompt" {
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/id_ed25519_personal"
  ssh_test() { return 0; }
  run ssh_ensure_key personal a@b
  [[ "$output" == *"present"* ]]
  [[ "$output" == *"$HOME/.ssh/id_ed25519_personal"* ]]
}

@test "missing key without tty warns and skips" {
  run ssh_ensure_key personal a@b
  [ "$status" -eq 0 ]
  [[ "$output" == *"no terminal"* ]]
  [ ! -f "$HOME/.ssh/id_ed25519_personal" ]
}

@test "dry run does not generate" {
  DRY_RUN=1 run ssh_ensure_key personal a@b
  [[ "$output" == *"[dry]"* ]]
}

@test "ssh_ensure_include creates config with include when absent" {
  ssh_ensure_include
  [ "$(head -1 "$HOME/.ssh/config")" = "Include ~/.ssh/conf.d/*.conf" ]
}

@test "ssh_ensure_include prepends to existing config without losing content" {
  mkdir -p "$HOME/.ssh"; printf 'Host coder.*\n  ProxyCommand x\n' > "$HOME/.ssh/config"
  ssh_ensure_include
  [ "$(head -1 "$HOME/.ssh/config")" = "Include ~/.ssh/conf.d/*.conf" ]
  grep -q 'ProxyCommand x' "$HOME/.ssh/config"
}

@test "ssh_ensure_include is idempotent" {
  ssh_ensure_include; ssh_ensure_include
  [ "$(grep -c 'Include ~/.ssh/conf.d' "$HOME/.ssh/config")" = 1 ]
}

@test "ssh_ensure_include dry run touches nothing" {
  DRY_RUN=1 run ssh_ensure_include
  [[ "$output" == *"[dry]"* ]]
  [ ! -e "$HOME/.ssh/config" ]
}

@test "ssh module install uses the profile being installed over the remembered one" {
  remember profile personal
  export DOTFILES_DIR DOTFILES_PROFILE=work
  run bash "$DOTFILES_DIR/modules/ssh/preflight.sh"
  [[ "$output" == *"skipping ssh key generation for work"* ]]
}

@test "ssh_ensure_include edits a symlinked config in place" {
  mkdir -p "$HOME/.ssh" "$HOME/real"; printf 'Host y\n' > "$HOME/real/sshconf"
  ln -s "$HOME/real/sshconf" "$HOME/.ssh/config"
  ssh_ensure_include
  [ -L "$HOME/.ssh/config" ]
  [ "$(head -1 "$HOME/real/sshconf")" = "Include ~/.ssh/conf.d/*.conf" ]
}

@test "ssh install.sh only ensures include" {
  run bash "$DOTFILES_DIR/modules/ssh/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ssh key"* ]]
  [ -f "$HOME/.ssh/config" ]
}

@test "ssh_test uses the key file directly, not the host alias" {
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\necho "$@" > "$HOME/ssh-args"; echo "successfully authenticated" >&2\n' > "$HOME/bin/ssh"; chmod +x "$HOME/bin/ssh"
  PATH="$HOME/bin:$PATH" ssh_test "$HOME/.ssh/id_ed25519_personal"
  grep -q -- "-i $HOME/.ssh/id_ed25519_personal" "$HOME/ssh-args"
  grep -q "git@github.com " "$HOME/ssh-args" || grep -q "git@github.com$" "$HOME/ssh-args"
}

# ---- phase 9: keys by candidate files ----
@test "each alias lists its candidate key files in order, the Coder account key last" {
  conf="$DOTFILES_DIR/modules/ssh/home/.ssh/conf.d/github.conf"
  run ssh -G -F "$conf" github.com-work
  [ "$(printf '%s\n' "$output" | sed -n 's/^identityfile //p')" = $'~/.ssh/id_ed25519_work\n~/.ssh/git-commit-signing/coder' ]
  [[ "$output" == *"identitiesonly yes"* ]]
  run ssh -G -F "$conf" github.com-personal
  [ "$(printf '%s\n' "$output" | sed -n 's/^identityfile //p')" = $'~/.ssh/id_ed25519_personal\n~/.ssh/git-commit-signing/coder' ]
  [ "$(ssh_key_candidates work)" = "$HOME/.ssh/id_ed25519_work"$'\n'"$HOME/.ssh/git-commit-signing/coder" ]
}

@test "the Coder account key counts as present: nothing is generated and the test uses that key" {
  mkdir -p "$HOME/.ssh/git-commit-signing"; touch "$HOME/.ssh/git-commit-signing/coder"
  ssh_test() { echo "TESTED $1"; }
  DOTFILES_TTY=/dev/null run ssh_ensure_key work a@b
  [ "$status" -eq 0 ]; [[ "$output" == *"present"* ]]
  [[ "$output" == *"TESTED $HOME/.ssh/git-commit-signing/coder"* ]]
  [ ! -e "$HOME/.ssh/id_ed25519_work" ]
}

@test "the generated key is preferred over the Coder key when both exist" {
  mkdir -p "$HOME/.ssh/git-commit-signing"; touch "$HOME/.ssh/git-commit-signing/coder" "$HOME/.ssh/id_ed25519_work"
  ssh_test() { echo "TESTED $1"; }
  run ssh_ensure_key work a@b
  [[ "$output" == *"TESTED $HOME/.ssh/id_ed25519_work"* ]]
}

@test "server-work preflight handles only the work identity" {
  export DOTFILES_DIR DOTFILES_PROFILE=server-work
  run bash "$DOTFILES_DIR/modules/ssh/preflight.sh"
  [[ "$output" == *"for work"* ]]; [[ "$output" != *personal* ]]
}
