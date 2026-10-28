load helper
setup() { setup_home; for f in log os link module vscode; do source "$DOTFILES_DIR/lib/$f.sh"; done; V="$DOTFILES_DIR/modules/vscode"; }
teardown() { teardown_home; }

@test "user dir per os" {
  if [ "$(os_name)" = macos ]; then [ "$(vscode_user_dir)" = "$HOME/Library/Application Support/Code/User" ]; else [ "$(vscode_user_dir)" = "$HOME/.config/Code/User" ]; fi
}

@test "extension ids ignore comments and case" {
  printf '# group\nPub.Name  # why\n\nother.ext\n' > "$HOME/e.txt"
  run vscode_ext_list "$HOME/e.txt"
  [ "$output" = $'pub.name\nother.ext' ]
}

@test "shipped extension list is well formed" {
  run vscode_ext_list "$V/extensions.txt"
  [ "$status" -eq 0 ]; [ "${#lines[@]}" -ge 30 ]
  for id in "${lines[@]}"; do [[ "$id" =~ ^[a-z0-9-]+\.[a-z0-9-]+$ ]]; done
  [[ "$output" == *catppuccin.catppuccin-vsc* ]] && [[ "$output" == *charliermarsh.ruff* ]] && [[ "$output" == *anthropic.claude-code* ]]
  [[ "$output" != *black-formatter* ]] && [[ "$output" != *cmake* ]]
}

@test "config files are valid jsonc" {
  for f in settings.json keybindings.json tasks.json snippets/cpp.json; do jsonc_valid "$V/config/$f"; done
  echo '{ bad' > "$HOME/bad.json"; ! jsonc_valid "$HOME/bad.json"
}

@test "settings pin theme, font, format on save and ruff" {
  grep -q '"workbench.colorTheme": "Catppuccin Mocha"' "$V/config/settings.json"
  grep -q 'JetBrainsMono Nerd Font' "$V/config/settings.json"
  grep -q '"editor.formatOnSave": true' "$V/config/settings.json"
  grep -q 'charliermarsh.ruff' "$V/config/settings.json"
  grep -q '"editor.linkedEditing": true' "$V/config/settings.json"
}
