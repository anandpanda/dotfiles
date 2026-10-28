load helper
L="modules/lazygit"
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "lazygit links config and, on macOS, the Application Support path too" {
  module_apply "$DOTFILES_DIR/$L" >/dev/null
  [ -L "$HOME/.config/lazygit" ]
  if [ "$(os_name)" = macos ]; then
    [ "$(readlink "$HOME/Library/Application Support/lazygit/config.yml")" = "$DOTFILES_DIR/$L/config/config.yml" ]
  fi
}

@test "lazygit config is valid yaml with the pager and theme" {
  c="$DOTFILES_DIR/$L/config/config.yml"
  if command -v lazygit >/dev/null; then
    run env HOME="$HOME" XDG_CONFIG_HOME="$HOME/.config" lazygit --config "$c" --print-config-dir
    [ "$status" -eq 0 ]
  fi
  grep -q 'pager: delta' "$c"; grep -q '^  pagers:' "$c"; grep -q "'#89b4fa'" "$c"; grep -q 'editPreset: vscode' "$c"
  grep -q 'nerdFontsVersion: "3"' "$c"
}

@test "lazygit reads our config on this machine" {
  command -v lazygit >/dev/null || skip "lazygit missing"
  module_apply "$DOTFILES_DIR/$L" >/dev/null
  run env HOME="$HOME" XDG_CONFIG_HOME="$HOME/.config" lazygit --print-config-dir
  [ -f "$output/config.yml" ]
}

@test "lazygit config uses the current pagers list form and launching does not rewrite it" {
  c="$DOTFILES_DIR/$L/config/config.yml"
  grep -q '^  pagers:' "$c"; ! grep -q '^  paging:' "$c"
  command -v lazygit >/dev/null || skip "lazygit missing"
  cp "$c" "$HOME/cfg.yml"; mkdir -p "$HOME/repo"; git -C "$HOME/repo" init -q
  (cd "$HOME/repo" && timeout 3 env HOME="$HOME" lazygit --config "$HOME/cfg.yml" </dev/null >/dev/null 2>&1 || true)
  cmp -s "$c" "$HOME/cfg.yml"
}
