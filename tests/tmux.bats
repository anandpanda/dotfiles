load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  # Fake tpm remote: a local repo with tags v3.0.0 and v3.1.0
  R="$HOME/tpm-remote"; git init -q "$R"; echo a > "$R/tpm"; git -C "$R" add -A
  git -C "$R" -c user.name=t -c user.email=t@t commit -qm one; git -C "$R" tag v3.0.0
  echo b > "$R/tpm"; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -qm two; git -C "$R" tag v3.1.0
  export TPM_REPO="$R"
}
teardown() { teardown_home; }

@test "tmux links conf and shell.zsh" {
  module_apply "$DOTFILES_DIR/modules/tmux" >/dev/null
  [ -L "$HOME/.config/tmux/tmux.conf" ]
  [ -L "$HOME/.config/zsh/rc.d/tmux.zsh" ]
}

@test "tmux conf parses" {
  command -v tmux >/dev/null || skip "tmux missing"
  run tmux -f "$DOTFILES_DIR/modules/tmux/config/tmux.conf" -L "bats$$" start-server \; kill-server
  [ "$status" -eq 0 ]
}

@test "install clones tpm at the pinned tag" {
  bash "$DOTFILES_DIR/modules/tmux/install.sh"
  [ "$(git -C "$HOME/.config/tmux/plugins/tpm" describe --tags)" = "v3.1.0" ]
}

@test "tpm at wrong tag is moved to pinned tag" {
  git clone -q --branch v3.0.0 "$R" "$HOME/.config/tmux/plugins/tpm"
  run bash "$DOTFILES_DIR/modules/tmux/install.sh"
  [[ "$output" == *"moved"* ]]
  [ "$(git -C "$HOME/.config/tmux/plugins/tpm" describe --tags)" = "v3.1.0" ]
}

@test "install rerun is a no-op" {
  bash "$DOTFILES_DIR/modules/tmux/install.sh" >/dev/null
  run bash "$DOTFILES_DIR/modules/tmux/install.sh"
  [[ "$output" == *"skip"* ]]
}

@test "plugins in conf are pinned" {
  grep -E "^set -g @plugin" "$DOTFILES_DIR/modules/tmux/config/tmux.conf" | grep -v "tmux-plugins/tpm'" | while read -r l; do [[ "$l" == *"#v"* ]]; done
  zsh -n "$DOTFILES_DIR/modules/tmux/shell.zsh"
}
