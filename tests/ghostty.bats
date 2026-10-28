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

@test "linux install: apt package when available, snap otherwise, checklist as last resort" {
  [ "$(os_name)" = linux ] || skip "linux only"
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
  printf '#!/usr/bin/env bash\necho "sudo $*" >> "$HOME/cmd.log"; exec "$@"\n' > "$HOME/bin/sudo"
  printf '#!/usr/bin/env bash\necho "apt-get $*" >> "$HOME/cmd.log"\n[ "$1" = install ] && [ -n "${APT_HAS:-}" ] && exit 0; [ "$1" = install ] && exit 100; exit 0\n' > "$HOME/bin/apt-get"
  printf '#!/usr/bin/env bash\necho "apt-cache $*" >> "$HOME/cmd.log"; [ -n "${APT_HAS:-}" ] && echo "ghostty:" ; exit 0\n' > "$HOME/bin/apt-cache"
  printf '#!/usr/bin/env bash\necho "snap $*" >> "$HOME/cmd.log"\n' > "$HOME/bin/snap"
  chmod +x "$HOME/bin/"*
  APT_HAS=1 run bash "$DOTFILES_DIR/modules/ghostty/install.sh"; [ "$status" -eq 0 ]
  grep -q "apt-get install.*ghostty" "$HOME/cmd.log"; ! grep -q "^snap" "$HOME/cmd.log"
  : > "$HOME/cmd.log"
  run bash "$DOTFILES_DIR/modules/ghostty/install.sh"; [ "$status" -eq 0 ]
  grep -q "snap install ghostty --classic" "$HOME/cmd.log"
  printf '#!/usr/bin/env bash\necho ghostty-present\n' > "$HOME/bin/ghostty"; chmod +x "$HOME/bin/ghostty"; : > "$HOME/cmd.log"
  run bash "$DOTFILES_DIR/modules/ghostty/install.sh"; [[ "$output" == *skip* ]]; [ ! -s "$HOME/cmd.log" ]
}

@test "install on macos is a no-op" {
  [ "$(os_name)" = macos ] || skip "macos only"
  run bash "$DOTFILES_DIR/modules/ghostty/install.sh"; [ "$status" -eq 0 ]; [ -z "$output" ]
}
