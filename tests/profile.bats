load helper
setup() {
  setup_home
  source "$DOTFILES_DIR/lib/log.sh"
  source "$DOTFILES_DIR/lib/profile.sh"
  PROFILES="$HOME/profiles"; mkdir -p "$PROFILES"
  export DOTFILES_PROFILES="$PROFILES"
  printf 'modules = ["a", "b"]\n' > "$PROFILES/base.toml"
  printf 'extends = "base"\nmodules = ["b", "c"]\noverlay = true\n' > "$PROFILES/child.toml"
  printf 'extends = "loop2"\n' > "$PROFILES/loop1.toml"
  printf 'extends = "loop1"\n' > "$PROFILES/loop2.toml"
}
teardown() { teardown_home; }

@test "base profile lists its modules" {
  run profile_modules base
  [ "$output" = $'a\nb' ]
}

@test "child unions parent first, deduplicated" {
  run profile_modules child
  [ "$output" = $'a\nb\nc' ]
}

@test "overlay flag follows the chain" {
  run profile_has_overlay base; [ "$status" -ne 0 ]
  run profile_has_overlay child; [ "$status" -eq 0 ]
}

@test "unknown profile fails" {
  run profile_modules nope
  [ "$status" -ne 0 ]
}

@test "rejects extends cycle" {
  run profile_modules loop1
  [ "$status" -ne 0 ]
  [[ "$output" == *"cycle"* ]]
}

@test "remember and recall round trip" {
  remember profile work
  [ "$(recall profile)" = "work" ]
  [ -f "$HOME/.config/dotfiles/profile" ]
}

@test "recall of unset key prints nothing and fails" {
  run recall missing
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "real profiles resolve" {
  unset DOTFILES_PROFILES
  run profile_modules work
  [[ "$output" == *"git"* ]]
  run profile_has_overlay work; [ "$status" -eq 0 ]
  run profile_has_overlay personal; [ "$status" -ne 0 ]
}

@test "multi-line module list parses" {
  printf 'modules = [\n  "a", "b",\n  "c",\n]\n' > "$PROFILES/multi.toml"
  run profile_modules multi
  [ "$output" = $'a\nb\nc' ]
}

@test "comments inside a multi-line list are ignored" {
  printf 'modules = [\n  "a", # first\n  "b",\n]\n' > "$PROFILES/c.toml"
  run profile_modules c
  [ "$output" = $'a\nb' ]
}

@test "server profiles resolve and carry no desktop modules" {
  unset DOTFILES_PROFILES
  run profile_modules server
  [ "$status" -eq 0 ]
  for m in zsh git mise cli; do [[ "$output" == *"$m"* ]]; done
  for m in ghostty fonts vscode docker macos lazygit; do [[ "$output" != *"$m"* ]]; done
  run profile_has_overlay server-work; [ "$status" -eq 0 ]
  run profile_modules server-work; [[ "$output" == *zsh* ]]
}
