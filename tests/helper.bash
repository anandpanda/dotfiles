# Shared setup for all bats files. Sources lib and isolates HOME.
setup_home() {
  export HOME
  HOME="$(mktemp -d)"
  export _TEST_HOME="$HOME"
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export DRY_RUN=0
  # mise resolves home from the user database, not $HOME: point every mise dir at
  # the temp home so no test reads or writes the real config, data, state or trust.
  export MISE_GLOBAL_CONFIG_FILE="$HOME/.config/mise/config.toml"
  export MISE_CONFIG_DIR="$HOME/.config/mise" MISE_DATA_DIR="$HOME/.local/share/mise"
  export MISE_STATE_DIR="$HOME/.local/state/mise" MISE_CACHE_DIR="$HOME/.cache/mise"
}
# Only ever removes the temp dir setup_home created. Never a real home.
teardown_home() {
  [ -n "${_TEST_HOME:-}" ] || return 0
  case "$_TEST_HOME" in
    /tmp/* | /var/folders/* | /private/var/folders/*) rm -rf "$_TEST_HOME" ;;
  esac
  unset _TEST_HOME
}
