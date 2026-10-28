load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "atuin links config and shell.zsh" {
  module_apply "$DOTFILES_DIR/modules/atuin" >/dev/null
  [ -L "$HOME/.config/atuin" ]
  [ -L "$HOME/.config/zsh/rc.d/atuin.zsh" ]
}

@test "atuin sync is off and up arrow is left alone" {
  grep -q '^auto_sync = false' "$DOTFILES_DIR/modules/atuin/config/config.toml"
  grep -q 'disable-up-arrow' "$DOTFILES_DIR/modules/atuin/shell.zsh"
  zsh -n "$DOTFILES_DIR/modules/atuin/shell.zsh"
}
