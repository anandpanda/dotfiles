load helper
A="modules/apps"
setup() { setup_home; for f in log os brew module; do source "$DOTFILES_DIR/lib/$f.sh"; done; mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"; }
teardown() { teardown_home; }

@test "apps module is macos only and its Brewfile lists every pick" {
  grep -q 'os = "macos"' "$DOTFILES_DIR/$A/module.toml"
  run brew_names "$DOTFILES_DIR/$A/Brewfile.macos"
  for c in raycast shottr jordanbaird-ice stats alt-tab todobar keka appcleaner monitorcontrol; do
    [[ "$output" == *"$c"* ]] || { echo "missing $c"; false; }
  done
  [[ "$output" != *obsidian* ]]; [[ "$output" != *brave* ]]; [[ "$output" != *chrome* ]]; [[ "$output" != *aerospace* ]]; [[ "$output" != *karabiner* ]]; grep -q '# cask "obsidian"' "$DOTFILES_DIR/$A/Brewfile.macos"
  # Third-party tap casks: tap declared, cask fully qualified and trusted (Homebrew 7 tap trust).
  grep -q '^tap "menubar-apps/menubar-apps"$' "$DOTFILES_DIR/$A/Brewfile.macos"
  grep -q '^cask "menubar-apps/menubar-apps/todobar", trusted: true$' "$DOTFILES_DIR/$A/Brewfile.macos"
  if grep -E '^cask "[^"/]+"' "$DOTFILES_DIR/$A/Brewfile.macos" | grep -q trusted; then echo "trusted: on a core cask"; false; fi
  [ ! -e "$DOTFILES_DIR/$A/doctor.sh" ] # the root doctor already checks every Brewfile cask
}

fake_defaults() { # CURRENT-VALUE ("" = unset); export answers with a plist like the real one
  cat > "$HOME/bin/defaults" <<FAKE
#!/usr/bin/env bash
echo "\$*" >> "\$HOME/defaults.log"
case "\$1" in
  export) printf '<?xml version="1.0" encoding="UTF-8"?>\\n<plist version="1.0"><dict>%s</dict></plist>\\n' \
    "$([ -n "$1" ] && printf '<key>holdShortcut</key><string>%s</string>' "$1")" ;;
esac
FAKE
  chmod +x "$HOME/bin/defaults"
}

@test "install sets AltTab's hold key to Command once, and respects dry run" {
  fake_defaults ""
  run bash "$DOTFILES_DIR/$A/install.sh"; [ "$status" -eq 0 ]
  grep -q 'write com.lwouis.alt-tab-macos holdShortcut -string ⌘' "$HOME/defaults.log"
  fake_defaults "⌘"; : > "$HOME/defaults.log"
  run bash "$DOTFILES_DIR/$A/install.sh"; [ "$status" -eq 0 ]; [[ "$output" == *"skip alttab"* ]]
  ! grep -q write "$HOME/defaults.log"
  fake_defaults ""; : > "$HOME/defaults.log"
  DRY_RUN=1 run bash "$DOTFILES_DIR/$A/install.sh"; [ "$status" -eq 0 ]
  ! grep -q write "$HOME/defaults.log"
}
