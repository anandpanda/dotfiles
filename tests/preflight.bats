load helper
setup() {
  setup_home
  for f in log os link profile module preflight; do source "$DOTFILES_DIR/lib/$f.sh"; done
  M="$HOME/mods"; mkdir -p "$M/a" "$M/b"
  printf '#!/usr/bin/env bash\necho "a $DOTFILES_PROFILE" >> "$HOME/log"\n' > "$M/a/preflight.sh"
  printf '#!/usr/bin/env bash\necho b >> "$HOME/log"\n' > "$M/b/preflight.sh"
  export DOTFILES_PROFILE=test
}
teardown() { teardown_home; }

@test "runs preflights in order with env" {
  preflight_run "$(printf '%s\n%s\n' "$M/a" "$M/b")"
  [ "$(cat "$HOME/log")" = $'a test\nb' ]
}

@test "module without preflight is skipped" {
  mkdir -p "$M/c"
  preflight_run "$M/c"
  [ ! -f "$HOME/log" ]
}

@test "failing preflight fails the run" {
  printf '#!/usr/bin/env bash\nexit 2\n' > "$M/a/preflight.sh"
  run bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/preflight.sh'; preflight_run '$M/a'"
  [ "$status" -ne 0 ]
}

@test "a preflight that reads stdin does not swallow later modules" {
  printf '#!/usr/bin/env bash\ncat >/dev/null; echo a >> "$HOME/log"\n' > "$M/a/preflight.sh"
  exec </dev/null
  preflight_run "$(printf '%s\n%s\n' "$M/a" "$M/b")"
  [ "$(cat "$HOME/log")" = $'a\nb' ]
}
