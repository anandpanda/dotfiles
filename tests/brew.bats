load helper
setup() {
  setup_home
  for f in log os brew; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "brew_concat merges files and drops comments and blanks" {
  printf '# c\nbrew "jq"\n\n' > "$HOME/a"; printf 'cask "ghostty"\nbrew "jq"\n' > "$HOME/b"
  run brew_concat "$HOME/a" "$HOME/b"
  [ "$output" = $'brew "jq"\ncask "ghostty"' ]
}

@test "brew_names extracts formula and cask names" {
  printf 'brew "jq"\ncask "ghostty"\ntap "x/y"\nbrew "koekeishiya/formulae/yabai", args: ["HEAD"]\n' > "$HOME/a"
  run brew_names "$HOME/a"
  [ "$output" = $'jq\nghostty\nyabai' ]
}

@test "brew_bundle in dry run does not call brew" {
  printf 'brew "jq"\n' > "$HOME/a"
  DRY_RUN=1 run brew_bundle "$HOME/a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry]"* ]]
}
