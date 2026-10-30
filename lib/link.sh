#!/usr/bin/env bash
# Idempotent symlinks and generated files with timestamped backups; install removes links it no longer makes.

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

# Adds DST to this run's link list when install exported one (module install.sh scripts inherit it).
_link_note() { [ -z "${DOTFILES_LINK_RUN:-}" ] || printf '%s\n' "$1" >>"$DOTFILES_LINK_RUN"; }

link_file() {
  local src="$1" dst="$2"
  [ -e "$src" ] || [ -L "$src" ] || {
    log_fail "link source missing: $src"
    return 1
  }
  _link_note "$dst"

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

# Write CONTENT and a newline to FILE unless it already holds exactly that.
put_file() { # FILE CONTENT
  if [ -f "$1" ] && [ "$(cat "$1")" = "$2" ]; then
    echo "skip $1"
  elif [ "$DRY_RUN" = 1 ]; then
    log_dry "write $1"
  else
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" >"$1.tmp" && mv "$1.tmp" "$1"
    echo "wrote $1"
  fi
}

links_record() { echo "$(state_dir)/links"; }

# Remove links in the last record that RUN_LIST lacks and that still point into the repos; RUN_LIST becomes the record.
links_prune() { # RUN_LIST
  local record dst cur
  record="$(links_record)"
  if [ -f "$record" ]; then
    while IFS= read -r dst; do
      if grep -qxF "$dst" "$1" || [ ! -L "$dst" ]; then continue; fi
      cur="$(readlink "$dst")"
      case "$cur" in "$DOTFILES_DIR"/* | "$(modules_root)"/* | "$(overlay_dir)"/*) ;; *) continue ;; esac
      if [ "$DRY_RUN" = 1 ]; then
        log_dry "remove stale link $dst"
      else
        rm "$dst"
        printf 'removed stale link %s\n' "$dst"
      fi
    done <"$record"
  fi
  [ "$DRY_RUN" = 1 ] || put_file "$record" "$(sort -u "$1")" >/dev/null
}
