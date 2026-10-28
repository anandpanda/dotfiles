#!/usr/bin/env bash
# Idempotent symlinking with timestamped backups. Never deletes.

: "${DRY_RUN:=0}"
# Fixed once per run, at source time, so every backup in a run shares one dir.
# (A lazy $(...) call would run in a subshell and never persist.)
: "${DOTFILES_BACKUP_ROOT:=$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
export DOTFILES_BACKUP_ROOT

backup_root() { echo "$DOTFILES_BACKUP_ROOT"; }

# Move DST into the backup tree, preserving its path relative to HOME.
_backup() {
  local dst="$1" rel dest
  rel="${dst#"$HOME"/}"
  dest="$(backup_root)/$rel"
  if [ "$DRY_RUN" = 1 ]; then
    log_dry "backup $dst -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  # Never overwrite an earlier backup of the same path.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local n=1
    while [ -e "$dest.$n" ] || [ -L "$dest.$n" ]; do n=$((n + 1)); done
    dest="$dest.$n"
  fi
  mv "$dst" "$dest"
  printf 'backup %s -> %s\n' "$dst" "$dest"
}

# Public: move DST into the backup tree (used by module hooks).
backup_move() { _backup "$1"; }

link_file() {
  local src="$1" dst="$2"
  [ -e "$src" ] || [ -L "$src" ] || {
    log_fail "link source missing: $src"
    return 1
  }

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf 'skip %s\n' "$dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    _backup "$dst"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log_dry "link $dst -> $src"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  printf 'link %s -> %s\n' "$dst" "$src"
}

# Link every regular file under SRC_DIR to the same relative path in DST_DIR.
link_tree() {
  local src_dir="$1" dst_dir="$2" f rel
  while IFS= read -r f; do
    rel="${f#"$src_dir"/}"
    link_file "$f" "$dst_dir/$rel"
  done < <(find "$src_dir" -type f | sort)
}
