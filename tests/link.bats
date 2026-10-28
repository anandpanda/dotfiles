load helper
setup() {
  setup_home
  source "$DOTFILES_DIR/lib/log.sh"
  source "$DOTFILES_DIR/lib/link.sh"
  SRC="$HOME/src"; mkdir -p "$SRC"; echo content > "$SRC/file"
}
teardown() { teardown_home; }

@test "links a new file and creates parent dirs" {
  link_file "$SRC/file" "$HOME/a/b/file"
  [ -L "$HOME/a/b/file" ]
  [ "$(readlink "$HOME/a/b/file")" = "$SRC/file" ]
}

@test "skips a correct existing symlink" {
  ln -s "$SRC/file" "$HOME/file"
  run link_file "$SRC/file" "$HOME/file"
  [[ "$output" == *"skip"* ]]
  [ -z "$(ls -A "$HOME/.dotfiles-backup" 2>/dev/null)" ]
}

@test "backs up identical regular file" {
  cp "$SRC/file" "$HOME/file"
  link_file "$SRC/file" "$HOME/file"
  [ -L "$HOME/file" ]
  [ "$(cat "$(backup_root)/file")" = "content" ]
}

@test "replaces wrong symlink and backs it up" {
  echo other > "$HOME/other"
  ln -s "$HOME/other" "$HOME/file"
  link_file "$SRC/file" "$HOME/file"
  [ "$(readlink "$HOME/file")" = "$SRC/file" ]
  [ -L "$(backup_root)/file" ]
}

@test "backs up a directory in the way" {
  mkdir -p "$HOME/dir"; echo x > "$HOME/dir/inner"
  link_file "$SRC" "$HOME/dir"
  [ -L "$HOME/dir" ]
  [ -f "$(backup_root)/dir/inner" ]
}

@test "dry run changes nothing" {
  DRY_RUN=1 run link_file "$SRC/file" "$HOME/file"
  [[ "$output" == *"[dry]"* ]]
  [ ! -e "$HOME/file" ]
}

@test "link_tree links every file preserving relative paths" {
  mkdir -p "$SRC/tree/.ssh"; echo c > "$SRC/tree/.ssh/config"; echo g > "$SRC/tree/.gitconfig"
  link_tree "$SRC/tree" "$HOME"
  [ "$(readlink "$HOME/.ssh/config")" = "$SRC/tree/.ssh/config" ]
  [ "$(readlink "$HOME/.gitconfig")" = "$SRC/tree/.gitconfig" ]
}

@test "fails when source missing" {
  run link_file "$SRC/nope" "$HOME/file"
  [ "$status" -ne 0 ]
}
