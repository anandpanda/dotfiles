load helper
setup() { setup_home; }
teardown() { teardown_home; }

@test "fonts brewfile has the nerd font cask" {
  grep -q 'cask "font-jetbrains-mono-nerd-font"' "$DOTFILES_DIR/modules/fonts/Brewfile"
}

@test "fonts on macos is a no-op script" {
  [ "$(uname -s)" = Darwin ] || skip "macos only"
  run bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
}

@test "fonts linux installs once into ~/.local/share/fonts" {
  [ "$(uname -s)" = Linux ] || skip "linux only"
  BIN="$HOME/bin"; mkdir -p "$BIN"
  printf '#!/usr/bin/env bash\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done; mkdir -p "$(dirname "$out")"; python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],\"w\"); z.writestr(\"f.ttf\",\"x\"); z.close()" "$out"\n' > "$BIN/curl"; chmod +x "$BIN/curl"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$BIN/fc-cache"; chmod +x "$BIN/fc-cache"
  PATH="$BIN:$PATH" run bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.local/share/fonts/JetBrainsMono/f.ttf" ]
  PATH="$BIN:$PATH" run bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [[ "$output" == *"skip"* ]]
}

@test "fonts linux without fc-cache warns" {
  [ "$(uname -s)" = Linux ] || skip "linux only"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMono"
  E="$HOME/emptybin"; mkdir -p "$E"; ln -s "$(command -v uname)" "$E/uname"
  PATH="$E" run /bin/bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fc-cache"* ]]
}

@test "fonts dry run downloads nothing" {
  [ "$(uname -s)" = Linux ] || skip "linux only"
  DRY_RUN=1 run bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [[ "$output" == *"[dry]"* ]]
  [ ! -d "$HOME/.local/share/fonts" ]
}
