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

@test "unknown remembered profile is a failure, not clean" {
  echo ghost > "$HOME/.config/dotfiles/profile"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" != *"doctor: clean"* ]]
}

@test "stale overlay is reported" {
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  "$DOTFILES_DIR/install.sh" w --overlay "$REMOTE" >/dev/null
  echo x > "$REMOTE/new"; git -C "$REMOTE" add -A; git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm new
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlay behind"* ]]
}

@test "missing ssh include line is reported" {
  unset DOTFILES_MODULES
  printf 'modules = ["ssh"]\n' > "$DOTFILES_PROFILES/s.toml"
  "$DOTFILES_DIR/install.sh" s >/dev/null
  printf 'Host x\n' > "$HOME/.ssh/config"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ssh include missing"* ]]
}

@test "missing rc.d link is reported" {
  echo 'x' > "$DOTFILES_MODULES/one/shell.zsh"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  rm "$HOME/.config/zsh/rc.d/one.zsh"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing link"*"rc.d/one.zsh"* ]]
}

@test "login shell not homebrew zsh is reported when zsh module enabled" {
  unset DOTFILES_MODULES
  printf 'modules = ["zsh"]\n' > "$DOTFILES_PROFILES/z.toml"
  DOTFILES_SKIP_BREW=1 "$DOTFILES_DIR/install.sh" z >/dev/null 2>&1 || true
  run "$DOTFILES_DIR/doctor.sh"
  [[ "$output" == *"login shell"* ]]
}

@test "config dirs populated file by file count as managed" {
  mkdir -p "$DOTFILES_MODULES/one/home/.config/foo"; touch "$DOTFILES_MODULES/one/home/.config/foo/x"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unmanaged"*"/foo"* ]]
}
