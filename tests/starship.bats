load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "starship links config and shell.zsh" {
  module_apply "$DOTFILES_DIR/modules/starship" >/dev/null
  [ -L "$HOME/.config/starship" ]
  [ -L "$HOME/.config/zsh/rc.d/starship.zsh" ]
}

@test "starship shell.zsh parses and points at the config" {
  zsh -n "$DOTFILES_DIR/modules/starship/shell.zsh"
  run zsh -c "source '$DOTFILES_DIR/modules/starship/shell.zsh'; echo \$STARSHIP_CONFIG"
  [ "$output" = "$HOME/.config/starship/starship.toml" ]
}

@test "starship config loads" {
  command -v starship >/dev/null || skip "starship missing"
  STARSHIP_CONFIG="$DOTFILES_DIR/modules/starship/config/starship.toml" run starship print-config
  [ "$status" -eq 0 ]
  [[ "$output" == *"catppuccin_mocha"* ]]
}
