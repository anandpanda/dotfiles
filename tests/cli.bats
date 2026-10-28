load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "cli module links bat, btop, yazi configs and shell.zsh" {
  module_apply "$DOTFILES_DIR/modules/cli" >/dev/null
  [ -L "$HOME/.config/bat/config" ]
  [ -L "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme" ]
  [ -L "$HOME/.config/btop/btop.conf" ]
  [ -L "$HOME/.config/btop/themes/catppuccin_mocha.theme" ]
  [ -L "$HOME/.config/yazi/yazi.toml" ]
  [ -L "$HOME/.config/yazi/theme.toml" ]
  [ -L "$HOME/.config/zsh/rc.d/cli.zsh" ]
}

@test "shell.zsh parses" {
  run zsh -n "$DOTFILES_DIR/modules/cli/shell.zsh"
  [ "$status" -eq 0 ]
}

@test "shell.zsh sources cleanly in a bare zsh" {
  run zsh -c "source '$DOTFILES_DIR/modules/cli/shell.zsh'; echo \$FZF_DEFAULT_COMMAND"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fd "* ]]
}

@test "bat theme is wired and loads" {
  command -v bat >/dev/null || skip "bat missing"
  module_apply "$DOTFILES_DIR/modules/cli" >/dev/null
  BAT_CONFIG_DIR="$HOME/.config/bat" BAT_CACHE_PATH="$HOME/.cache/bat" bat cache --build >/dev/null
  run env BAT_CONFIG_DIR="$HOME/.config/bat" BAT_CACHE_PATH="$HOME/.cache/bat" bat --list-themes
  [[ "$output" == *"Catppuccin Mocha"* ]]
}

@test "brewfile lists the stack" {
  for t in eza bat ripgrep fd zoxide fzf git-delta yazi dust btop jq tealdeer; do
    grep -q "\"$t\"" "$DOTFILES_DIR/modules/cli/Brewfile"
  done
}
