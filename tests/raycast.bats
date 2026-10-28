load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "raycast module links script commands and is macos only" {
  module_apply "$DOTFILES_DIR/modules/raycast" >/dev/null
  [ -L "$HOME/.config/raycast/scripts/dots-doctor.sh" ]
  grep -q '@raycast.schemaVersion' "$DOTFILES_DIR/modules/raycast/home/.config/raycast/scripts/dots-doctor.sh"
  grep -q 'os = "macos"' "$DOTFILES_DIR/modules/raycast/module.toml"
  grep -qi "Cmd-Space" "$DOTFILES_DIR/modules/raycast/CHECKLIST.macos.md"
}
