#!/usr/bin/env bash
# ~/.gitconfig is the machine's own file; its first line includes the repo's git config.

gitconfig_include_line() { echo '[include] path = ~/.config/git/base.gitconfig'; }

# Git takes the first matching url rewrite and the last value of a single-valued key, so
# with our include first our rewrites win and what other tools append below stays in force.
gitconfig_ensure_include() {
  local cfg="$HOME/.gitconfig" line tmp
  line="$(gitconfig_include_line)"
  if [ ! -L "$cfg" ] && [ -f "$cfg" ] && [ "$(head -1 "$cfg")" = "$line" ]; then
    echo "skip $cfg"
    return 0
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "write $cfg"
    return 0
  fi
  [ ! -L "$cfg" ] || backup_move "$cfg"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$line"
    [ ! -f "$cfg" ] || cat "$cfg"
  } >"$tmp"
  cat "$tmp" >"$cfg" && rm -f "$tmp"
  echo "wrote $cfg"
}
