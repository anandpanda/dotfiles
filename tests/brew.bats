load helper
setup() {
  setup_home
  for f in log os brew; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "brew_concat merges files and drops comments and blanks" {
  printf '# c\nbrew "jq"\n\n' > "$HOME/a"; printf 'cask "ghostty"\nbrew "jq"\n' > "$HOME/b"
  run brew_concat "$HOME/a" "$HOME/b"
  [ "$output" = $'brew "jq"\ncask "ghostty"' ]
}

@test "brew_names extracts formula and cask names" {
  printf 'brew "jq"\ncask "ghostty"\ntap "x/y"\nbrew "koekeishiya/formulae/yabai", args: ["HEAD"]\n' > "$HOME/a"
  run brew_names "$HOME/a"
  [ "$output" = $'jq\nghostty\nyabai' ]
}

@test "brew_bundle in dry run does not call brew" {
  printf 'brew "jq"\n' > "$HOME/a"
  DRY_RUN=1 run brew_bundle "$HOME/a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry]"* ]]
}

@test "brew_missing matches whole names only" {
  brew() { case "$2" in --formula) printf 'git-lfs\nlibgit2\n' ;; --cask) : ;; esac; }
  printf 'brew "git"\nbrew "git-lfs"\n' > "$HOME/a"
  run brew_missing "$HOME/a"
  [ "$output" = "git" ]
}


@test "brew_ensure on linux without sudo dies clearly when prerequisites are missing, proceeds when present" {
  [ "$(os_name)" = linux ] || skip "linux only"
  mkdir -p "$HOME/bin"
  # No brew, no sudo, basics present (faked: the runner may lack gcc) -> reaches the installer
  # step, where the stubbed curl fails fast.
  for c in git gcc make; do printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/$c"; done
  printf '#!/usr/bin/env bash\nexit 7\n' > "$HOME/bin/curl"; chmod +x "$HOME/bin/"*
  run env PATH="$HOME/bin:/usr/bin:/bin" bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/os.sh'; source '$DOTFILES_DIR/lib/brew.sh'; brew_prefix() { echo '$HOME/nobrew'; }; os_name() { echo linux; }; brew_ensure"
  [[ "$output" != *"sudo is not available"* ]]; [ "$status" -ne 0 ]
  [[ "$output" == *"homebrew install failed"* ]] || [[ "$output" == *"bin/brew is missing"* ]]
  # Basics missing: a PATH with only bash, coreutils-free fakes and a failing sudo. `command -v`
  # is existence, so the basics must truly be absent from PATH.
  mkdir -p "$HOME/minimal"; for c in bash sh env printf head cut grep; do p="$(command -v $c)"; [ -n "$p" ] && ln -sf "$p" "$HOME/minimal/$c"; done
  printf '#!/usr/bin/env bash\nexit 1\n' > "$HOME/minimal/sudo"; chmod +x "$HOME/minimal/sudo"
  run env PATH="$HOME/minimal" bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/os.sh'; source '$DOTFILES_DIR/lib/brew.sh'; brew_prefix() { echo '$HOME/nobrew'; }; os_name() { echo linux; }; brew_ensure"
  [ "$status" -ne 0 ]; [[ "$output" == *"sudo is not available"* ]]
}

@test "brew_ensure installs Homebrew at brew_prefix through the installer's --path" {
  mkdir -p "$HOME/bin"
  for c in git gcc make; do printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/$c"; done
  cat > "$HOME/installer" <<'SH'
echo "$@" > "$HOME/installer-args"
p="${1#--path=}"; mkdir -p "$p/bin"; printf '#!/usr/bin/env bash\ncase "$1" in shellenv) echo "export PATH=\\"%s/bin:\\$PATH\\"" ;; --version) echo "Homebrew 9.9.9" ;; esac\n' "$p" > "$p/bin/brew"; chmod +x "$p/bin/brew"
SH
  printf '#!/usr/bin/env bash\ncat "%s/installer"\n' "$HOME" > "$HOME/bin/curl"; chmod +x "$HOME/bin/"*
  run env PATH="$HOME/bin:/usr/bin:/bin" bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/os.sh'; source '$DOTFILES_DIR/lib/brew.sh'; os_name() { echo linux; }; brew_ensure"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/installer-args")" = "--path=$HOME/.brew" ]
  [[ "$output" == *"Homebrew 9.9.9"* ]]
}

@test "brew_missing on linux leaves out casks that depend on macOS, on macos reports them" {
  brew() {
    case "$1 $2" in
      "list --formula") echo jq ;;
      "list --cask") : ;;
      "info --cask") echo '{"casks":[{"token":"mac-app","depends_on":{"macos":{}}},{"token":"some-font","depends_on":{}}]}' ;;
    esac
  }
  printf 'brew "jq"\ncask "mac-app"\ncask "some-font"\n' > "$HOME/a"
  os_name() { echo linux; }
  run brew_missing "$HOME/a"
  [ "$output" = "some-font" ] || false
  os_name() { echo macos; }
  run brew_missing "$HOME/a"
  [ "$output" = $'mac-app\nsome-font' ]
}
