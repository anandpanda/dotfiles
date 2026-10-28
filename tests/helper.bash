# Shared setup for all bats files. Sources lib and isolates HOME.
setup_home() {
  export HOME
  HOME="$(mktemp -d)"
  export _TEST_HOME="$HOME"
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export DRY_RUN=0
}
# Only ever removes the temp dir setup_home created. Never a real home.
teardown_home() {
  [ -n "${_TEST_HOME:-}" ] || return 0
  case "$_TEST_HOME" in
    /tmp/* | /var/folders/* | /private/var/folders/*) rm -rf "$_TEST_HOME" ;;
  esac
  unset _TEST_HOME
}
