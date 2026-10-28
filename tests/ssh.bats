load helper
setup() {
  setup_home
  for f in log profile ssh; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "key path per context" {
  [ "$(ssh_key_path work)" = "$HOME/.ssh/id_ed25519_work" ]
}

@test "contexts: personal only, work adds work" {
  run ssh_contexts_for_profile personal; [ "$output" = "personal" ]
  run ssh_contexts_for_profile work; [ "$output" = $'personal\nwork' ]
}

@test "existing key is reported present, no prompt" {
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/id_ed25519_personal"
  ssh_test() { return 0; }
  run ssh_ensure_key personal a@b
  [[ "$output" == *"present"* ]]
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
