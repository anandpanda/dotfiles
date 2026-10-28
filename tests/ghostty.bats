load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "ghostty links config" {
  module_apply "$DOTFILES_DIR/modules/ghostty" >/dev/null
  [ -L "$HOME/.config/ghostty" ]
  [ -f "$HOME/.config/ghostty/config" ]
}

@test "ghostty brewfile has the cask" {
  grep -q 'cask "ghostty"' "$DOTFILES_DIR/modules/ghostty/Brewfile"
}

@test "ghostty config validates" {
  command -v ghostty >/dev/null || [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ] || skip "ghostty missing"
  g="$(command -v ghostty || echo /Applications/Ghostty.app/Contents/MacOS/ghostty)"
  run "$g" +validate-config --config-file="$DOTFILES_DIR/modules/ghostty/config/config"
  [ "$status" -eq 0 ]
}
