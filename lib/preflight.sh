#!/usr/bin/env bash
# Everything that needs a human runs here, after packages and before any config changes.
# Reads module dirs one per line on stdin; runs each preflight.sh in order.

preflight_run() {
  local d name list
  list="$(cat)" # slurp first: scripts below must see the real stdin, not this list
  while IFS= read -r d <&3; do
    [ -n "$d" ] && [ -f "$d/preflight.sh" ] || continue
    name="$(basename "$d")"
    log_info "preflight: $name"
    DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" \
      DOTFILES_PROFILE="${DOTFILES_PROFILE:-}" bash "$d/preflight.sh" ||
      {
        log_fail "preflight $name failed"
        return 1
      }
  done 3<<<"$list"
  return 0
}
