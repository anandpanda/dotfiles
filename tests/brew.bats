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
  [[ "$output" != *"sudo is not available"* ]]
  # Basics missing and no sudo -> clear die.
  run env PATH="$HOME/emptybin" bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/os.sh'; source '$DOTFILES_DIR/lib/brew.sh'; brew_prefix() { echo '$HOME/nobrew'; }; os_name() { echo linux; }; brew_ensure"
  [ "$status" -ne 0 ]; [[ "$output" == *"sudo is not available"* ]]
}
