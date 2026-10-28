load helper
setup() {
  setup_home
  export DOTFILES_PROFILES="$HOME/profiles"; mkdir -p "$DOTFILES_PROFILES"
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES/one/config"; touch "$DOTFILES_MODULES/one/config/x"
  printf 'modules = ["one"]\n' > "$DOTFILES_PROFILES/test.toml"
  export DOTFILES_SKIP_BREW=1
  "$DOTFILES_DIR/install.sh" test >/dev/null
}
teardown() { teardown_home; }

@test "clean machine passes" {
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile: test"* ]]
}

@test "missing link is reported" {
  rm "$HOME/.config/one"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing link"*".config/one"* ]]
}

@test "wrong link is reported" {
  rm "$HOME/.config/one"; ln -s /tmp "$HOME/.config/one"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wrong link"* ]]
}

@test "unmanaged config entry is listed as info, not failure" {
  mkdir -p "$HOME/.config/stray"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmanaged"*"stray"* ]]
}

@test "missing overlay for work-style profile is a problem" {
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  echo w > "$HOME/.config/dotfiles/profile"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlay missing"* ]]
}
