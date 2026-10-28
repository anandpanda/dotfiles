#!/usr/bin/env bash
# Homebrew on macOS and Linux. One bundle from all enabled modules' Brewfiles.

brew_ensure() {
  if ! command -v brew >/dev/null 2>&1; then
    if [ -x "$(brew_prefix)/bin/brew" ]; then
      eval "$("$(brew_prefix)/bin/brew" shellenv)"
      return 0
    fi
    if [ "${DRY_RUN:-0}" = 1 ]; then
      log_dry "install homebrew"
      return 0
    fi
    log_info "installing Homebrew"
    if [ "$(os_name)" = linux ]; then
      sudo apt-get update -qq && sudo apt-get install -y -qq build-essential curl file git procps >/dev/null
    fi
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$("$(brew_prefix)/bin/brew" shellenv)"
  fi
  log_ok "homebrew $(brew --version | head -1)"
}

# Merge Brewfiles: drop comments and blank lines, dedupe, keep first order.
brew_concat() {
  cat "$@" | sed 's/[[:space:]]*#.*$//' | grep -v '^[[:space:]]*$' | awk '!seen[$0]++'
}

# Bare names of brew and cask entries, last path component, no args.
brew_names() {
  brew_concat "$@" | sed -E -n 's/^(brew|cask) "([^"]*)".*/\2/p' | sed 's|.*/||'
}

brew_bundle() {
  local tmp
  [ "$#" -gt 0 ] || return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "brew bundle: $(brew_names "$@" | tr '\n' ' ')"
    return 0
  fi
  tmp="$(mktemp)"
  brew_concat "$@" >"$tmp"
  log_info "brew bundle ($(wc -l <"$tmp" | tr -d ' ') entries)"
  brew bundle --file="$tmp" --no-upgrade
  rm -f "$tmp"
}

# brew_bundle with Brewfile paths one per line on stdin.
brew_bundle_stdin() {
  local f files=()
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || return 0
  brew_bundle "${files[@]}"
}

# Names from the Brewfiles that brew does not report as installed.
brew_missing() {
  local installed n
  installed="$(
    brew list --formula -1 2>/dev/null
    brew list --cask -1 2>/dev/null
  )"
  for n in $(brew_names "$@"); do
    grep -qxF "$n" <<<"$installed" || echo "$n"
  done
}

brew_missing_stdin() {
  local f files=()
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || return 0
  brew_missing "${files[@]}"
}
