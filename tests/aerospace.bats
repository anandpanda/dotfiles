load helper
C="modules/aerospace/home/.config/aerospace/aerospace.toml"
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "aerospace config parses and carries the agreed binds and floats" {
  python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" "$DOTFILES_DIR/$C"
  for k in "alt-h = 'focus left'" "alt-shift-l = 'move right'" "alt-1 = 'workspace 1'" "alt-shift-1 = 'move-node-to-workspace 1'" "alt-f = 'fullscreen'" "alt-tab = 'workspace-back-and-forth'" "alt-enter" "start-at-login = true"; do
    grep -qF "$k" "$DOTFILES_DIR/$C" || { echo "missing $k"; false; }
  done
  for app in com.apple.finder com.apple.systempreferences com.raycast.macos; do grep -q "$app" "$DOTFILES_DIR/$C"; done
  grep -q 'os = "macos"' "$DOTFILES_DIR/modules/aerospace/module.toml"
}

@test "aerospace config is linked only at ~/.config/aerospace" {
  module_apply "$DOTFILES_DIR/modules/aerospace" >/dev/null
  [ -L "$HOME/.config/aerospace/aerospace.toml" ]; [ ! -e "$HOME/.aerospace.toml" ]
}

@test "aerospace accepts the config" {
  # AeroSpace has no offline validator: only the running app (with Accessibility granted)
  # can load a config. When it runs our linked file, a reload must succeed.
  command -v aerospace >/dev/null || skip "aerospace missing"
  active="$(aerospace config --config-path 2>/dev/null)" || skip "aerospace server not running"
  [ "$active" -ef "$DOTFILES_DIR/$C" ] || skip "aerospace runs another config: $active"
  run aerospace reload-config
  [ "$status" -eq 0 ]
  run aerospace config --get mode.main.binding.alt-h
  [ "$status" -eq 0 ]; [[ "$output" == *"focus left"* ]]
}
