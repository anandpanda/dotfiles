load helper
R="modules/raycast"
S="$R/home/.config/raycast/scripts/dots-doctor.sh"
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"; }
teardown() { teardown_home; }

@test "raycast module links an executable script command with the required header" {
  module_apply "$DOTFILES_DIR/$R" >/dev/null
  [ -L "$HOME/.config/raycast/scripts/dots-doctor.sh" ]
  [ -x "$DOTFILES_DIR/$S" ]
  grep -q '^# @raycast.schemaVersion 1$' "$DOTFILES_DIR/$S"
  grep -q '^# @raycast.title ' "$DOTFILES_DIR/$S"
  grep -q '^# @raycast.mode fullOutput$' "$DOTFILES_DIR/$S"
  grep -q 'os = "macos"' "$DOTFILES_DIR/$R/module.toml"
  grep -qi "Cmd-Space" "$DOTFILES_DIR/$R/CHECKLIST.macos.md"
}

@test "the script finds the checkout through its link, wherever the repo lives" {
  module_apply "$DOTFILES_DIR/$R" >/dev/null
  printf '#!/bin/sh\necho "$@"\n' > "$HOME/bin/just"; chmod +x "$HOME/bin/just"
  run "$HOME/.config/raycast/scripts/dots-doctor.sh"
  [ "$status" -eq 0 ]
  want="$(cd "$DOTFILES_DIR" && pwd -P)"
  [ "$output" = "--justfile $want/justfile --working-directory $want doctor" ]
}
