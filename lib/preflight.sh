#!/usr/bin/env bash
# Everything that needs a human runs here, after packages and before any config changes.
# Reads module dirs one per line on stdin; runs each preflight.sh in order.

preflight_run() {
  local d name
  while IFS= read -r d; do
    [ -n "$d" ] && [ -f "$d/preflight.sh" ] || continue
    name="$(basename "$d")"
    log_info "preflight: $name"
    DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" \
      DOTFILES_PROFILE="${DOTFILES_PROFILE:-}" bash "$d/preflight.sh" ||
      {
        log_fail "preflight $name failed"
        return 1
      }
  done
  return 0
}
