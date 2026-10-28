#!/usr/bin/env bash
# A module is a folder: Brewfile, config/, home/, install.sh, module.toml, CHECKLIST.md, all optional.

module_enabled_for_os() {
  local toml="$1/module.toml" want
  [ -f "$toml" ] || return 0
  want="$(sed -n 's/^[[:space:]]*os[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$toml" | head -1)"
  [ -z "$want" ] || [ "$want" = "$(os_name)" ]
}

overlay_dir() { echo "${DOTFILES_OVERLAY_DIR:-$HOME/.dotfiles-work}"; }
modules_root() { echo "${DOTFILES_MODULES:-$DOTFILES_DIR/modules}"; }

# True when PATH is inside the overlay checkout.
_in_overlay() { case "$1" in "$(overlay_dir)"/*) return 0 ;; *) return 1 ;; esac }

# For an OVERLAY module NAME: if ~/.config/NAME already links to the public
# module's config dir, print that dir so our files get laid inside it.
# Any other situation (public module, foreign checkout, no link) prints nothing.
module_config_owner() { # NAME MODULE_DIR
  local owner public
  _in_overlay "$2" || return 1
  public="$(modules_root)/$1/config"
  owner="$(readlink "$HOME/.config/$1" 2>/dev/null || true)"
  if [ -z "$owner" ] || [ "$owner" != "$public" ] || [ ! -d "$owner" ]; then return 1; fi
  echo "$owner"
}

# Lay SRC_DIR's files inside DST_DIR, adding only: an existing real file is
# a tracked public file and is left alone.
_link_tree_add_only() {
  local src_dir="$1" dst_dir="$2" f rel dst
  while IFS= read -r f; do
    rel="${f#"$src_dir"/}"
    dst="$dst_dir/$rel"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      log_warn "skip $dst: public file exists, overlay cannot replace it"
      continue
    fi
    link_file "$f" "$dst" || return 1
  done < <(find "$src_dir" -type f | sort)
}

# Link home/ files; a public module never touches a file the overlay already owns.
_link_home() { # MODULE_DIR
  local dir="$1" f rel dst cur
  while IFS= read -r f; do
    rel="${f#"$dir"/home/}"
    dst="$HOME/$rel"
    cur="$(readlink "$dst" 2>/dev/null || true)"
    if ! _in_overlay "$dir" && [ -n "$cur" ] && _in_overlay "$cur"; then
      printf 'skip %s (overlay owns)\n' "$dst"
      continue
    fi
    link_file "$f" "$dst" || return 1
  done < <(find "$dir/home" -type f | sort)
}

rcd_dir() { echo "$HOME/.config/zsh/rc.d"; }

module_apply() {
  local dir="$1" name
  name="$(basename "$dir")"
  log_info "module: $name"
  if [ -d "$dir/config" ]; then
    local target="$HOME/.config/$name" owner
    if owner="$(module_config_owner "$name" "$dir")"; then
      _link_tree_add_only "$dir/config" "$owner" || return 1
    else
      link_file "$dir/config" "$target" || return 1
    fi
  fi
  if [ -d "$dir/home" ]; then
    _link_home "$dir" || return 1
  fi
  if [ -f "$dir/shell.zsh" ]; then
    local rc
    rc="$(rcd_dir)/$name.zsh"
    _in_overlay "$dir" && rc="$(rcd_dir)/$name.overlay.zsh"
    link_file "$dir/shell.zsh" "$rc" || return 1
  fi
  if [ -f "$dir/install.sh" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
      log_dry "run $dir/install.sh"
    else
      DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" bash "$dir/install.sh" ||
        {
          log_fail "module $name install.sh failed"
          return 1
        }
    fi
  fi
}

module_brewfiles() {
  local d
  for d in "$@"; do [ -f "$d/Brewfile" ] && echo "$d/Brewfile"; done
  return 0
}

module_checklists() {
  local d
  for d in "$@"; do [ -f "$d/CHECKLIST.md" ] && cat "$d/CHECKLIST.md"; done
  return 0
}

# Same, reading module dirs one per line from stdin (safe for paths with spaces).
module_brewfiles_stdin() {
  local d
  while IFS= read -r d; do [ -n "$d" ] && [ -f "$d/Brewfile" ] && echo "$d/Brewfile"; done
  return 0
}
# CHECKLIST.md always; CHECKLIST.<os>.md only on that OS.
module_checklists_stdin() {
  local d os
  os="$(os_name)"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ -f "$d/CHECKLIST.md" ] && cat "$d/CHECKLIST.md"
    [ -f "$d/CHECKLIST.$os.md" ] && cat "$d/CHECKLIST.$os.md"
  done
  return 0
}
