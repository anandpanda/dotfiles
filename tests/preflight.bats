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
  printf '%s\n%s\n' "$M/a" "$M/b" | preflight_run
  [ "$(cat "$HOME/log")" = $'a test\nb' ]
}

@test "module without preflight is skipped" {
  mkdir -p "$M/c"
  printf '%s\n' "$M/c" | preflight_run
  [ ! -f "$HOME/log" ]
}

@test "failing preflight fails the run" {
  printf '#!/usr/bin/env bash\nexit 2\n' > "$M/a/preflight.sh"
  run bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/preflight.sh'; printf '%s\n' '$M/a' | preflight_run"
  [ "$status" -ne 0 ]
}

@test "a preflight that reads stdin does not swallow later modules" {
  printf '#!/usr/bin/env bash\ncat >/dev/null; echo a >> "$HOME/log"\n' > "$M/a/preflight.sh"
  printf '%s\n%s\n' "$M/a" "$M/b" | preflight_run
  [ "$(cat "$HOME/log")" = $'a\nb' ]
}
