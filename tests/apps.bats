load helper
A="modules/apps"
setup() { setup_home; for f in log os brew module; do source "$DOTFILES_DIR/lib/$f.sh"; done; mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"; }
teardown() { teardown_home; }

@test "apps module is macos only and its Brewfile lists every pick" {
  grep -q 'os = "macos"' "$DOTFILES_DIR/$A/module.toml"
  run brew_names "$DOTFILES_DIR/$A/Brewfile.macos"
  for c in raycast aerospace karabiner-elements shottr jordanbaird-ice stats alt-tab brave-browser google-chrome todobar keka appcleaner monitorcontrol; do
    [[ "$output" == *"$c"* ]] || { echo "missing $c"; false; }
  done
  [[ "$output" != *obsidian* ]]; grep -q '# cask "obsidian"' "$DOTFILES_DIR/$A/Brewfile.macos"
  grep -q '^tap "nikitabobko/tap"' "$DOTFILES_DIR/$A/Brewfile.macos"
}

@test "doctor reports a missing cask and passes when all are present" {
  cat > "$HOME/bin/brew" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in "list --cask") cat "$HOME/casks.txt" ;; esac
FAKE
  chmod +x "$HOME/bin/brew"
  brew_names "$DOTFILES_DIR/$A/Brewfile.macos" > "$HOME/casks.txt"
  run bash "$DOTFILES_DIR/$A/doctor.sh"; [ "$status" -eq 0 ]
  grep -v raycast "$HOME/casks.txt" > "$HOME/c2"; mv "$HOME/c2" "$HOME/casks.txt"
  run bash "$DOTFILES_DIR/$A/doctor.sh"; [ "$status" -ne 0 ]; [[ "$output" == *"missing cask raycast"* ]]
}
