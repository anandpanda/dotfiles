load helper
setup() { setup_home; for f in log file; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "file_ensure_first_line creates a missing file with the line" {
  run file_ensure_first_line "$HOME/a/f" "first"
  [ "$output" = "wrote $HOME/a/f" ] || false
  [ "$(cat "$HOME/a/f")" = "first" ]
}

@test "file_ensure_first_line puts the line first and keeps the rest, once" {
  printf 'one\ntwo\n' > "$HOME/f"
  file_ensure_first_line "$HOME/f" "first" >/dev/null
  run file_ensure_first_line "$HOME/f" "first"
  [ "$output" = "skip $HOME/f" ] || false
  [ "$(cat "$HOME/f")" = $'first\none\ntwo' ]
}

@test "file_ensure_first_line edits a symlinked file at its target" {
  printf 'x\n' > "$HOME/target"; ln -s "$HOME/target" "$HOME/f"
  file_ensure_first_line "$HOME/f" "first" >/dev/null
  [ -L "$HOME/f" ] || false
  [ "$(head -1 "$HOME/target")" = "first" ]
}

@test "file_ensure_first_line dry run touches nothing" {
  DRY_RUN=1 run file_ensure_first_line "$HOME/f" "first"
  [[ "$output" == *"[dry]"* ]] || false
  [ ! -e "$HOME/f" ]
}
