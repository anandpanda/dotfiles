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

# Hermetic full installs: puts logging fakes for every external tool a module can
# reach (network, package managers, editors, Claude, containers, system settings)
# first on PATH. Each fake appends "args" to $HOME/calls/<tool> and exits 0 silently.
# Also points the tmux module at a local tpm repo so no clone leaves the machine.
# A test that needs different behaviour puts its own fake earlier on PATH.
stub_externals() {
  local t
  mkdir -p "$HOME/stubs" "$HOME/calls"
  for t in code claude curl wget brew mise gh docker sudo apt-get apt-cache snap defaults chsh; do
    printf '#!/bin/sh\necho "$*" >> "%s/calls/%s"\nexit 0\n' "$HOME" "$t" > "$HOME/stubs/$t"
    chmod +x "$HOME/stubs/$t"
  done
  export PATH="$HOME/stubs:$PATH"
  local r="$HOME/tpm-remote"
  if [ ! -d "$r/.git" ]; then
    git init -q "$r"; echo a > "$r/tpm"; git -C "$r" add -A
    git -C "$r" -c user.name=t -c user.email=t@t commit -qm one; git -C "$r" tag v3.1.0
  fi
  export TPM_REPO="$r"
}
