#!/usr/bin/env bash
# A module is a folder: Brewfile, config/, home/, install.sh, module.toml, CHECKLIST.md, all optional.

module_enabled_for_os() {
  local toml="$1/module.toml" want
  [ -f "$toml" ] || return 0
  want="$(sed -n 's/^[[:space:]]*os[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$toml" | head -1)"
  [ -z "$want" ] || [ "$want" = "$(os_name)" ]
}

module_apply() {
  local dir="$1" name
  name="$(basename "$dir")"
  log_info "module: $name"
  if [ -d "$dir/config" ]; then
    link_file "$dir/config" "$HOME/.config/$name" || return 1
  fi
  if [ -d "$dir/home" ]; then
    link_tree "$dir/home" "$HOME" || return 1
  fi
  if [ -x "$dir/install.sh" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
      log_dry "run $dir/install.sh"
    else
      DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" "$dir/install.sh" ||
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
