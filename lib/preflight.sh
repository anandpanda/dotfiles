#!/usr/bin/env bash
# Everything that needs a human runs here, after packages and before any config changes.
# Takes module dirs one per line as $1 (never stdin: the scripts must see the real terminal).

preflight_run() {
  local list="$1" d name
  while IFS= read -r d <&3; do
    if [ -z "$d" ] || [ ! -f "$d/preflight.sh" ]; then continue; fi
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
