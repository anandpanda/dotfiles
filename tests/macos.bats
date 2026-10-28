load helper
# Puts a fake `defaults` first on PATH that logs every call and answers reads from a file.
setup() {
  setup_home
  BIN="$HOME/bin"; mkdir -p "$BIN"
  cat > "$BIN/defaults" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/defaults.log"
if [ "$1" = read ]; then
  grep -F "$2 $3=" "$HOME/defaults.db" 2>/dev/null | head -1 | sed 's/.*=//' || true
  grep -Fq "$2 $3=" "$HOME/defaults.db" 2>/dev/null || { echo "not found" >&2; exit 1; }
fi
[ "$1" = write ] && echo "$2 $3=$5" >> "$HOME/defaults.db"
exit 0
FAKE
  chmod +x "$BIN/defaults"
  cat > "$BIN/killall" <<'FAKE'
#!/usr/bin/env bash
echo "killall $*" >> "$HOME/defaults.log"
FAKE
  chmod +x "$BIN/killall"
  export PATH="$BIN:$PATH"
  export DRY_RUN=0
}
teardown() { teardown_home; }

@test "dry run writes nothing" {
  DRY_RUN=1 run "$DOTFILES_DIR/modules/macos/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry] defaults write"* ]]
  ! grep -q '^write' "$HOME/defaults.log"
}

@test "first run writes and restarts, second run is silent" {
  run "$DOTFILES_DIR/modules/macos/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"set com.apple.dock autohide ="* ]]
  grep -q '^killall' "$HOME/defaults.log"
  rm "$HOME/defaults.log"
  run "$DOTFILES_DIR/modules/macos/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"set "* ]]
  ! grep -q '^write' "$HOME/defaults.log"
}

@test "bool compare treats 1 as true" {
  echo "com.apple.dock autohide=1" > "$HOME/defaults.db"
  run "$DOTFILES_DIR/modules/macos/install.sh"
  [[ "$output" != *"set com.apple.dock autohide ="* ]]
}
