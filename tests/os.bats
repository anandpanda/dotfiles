load helper
setup() { setup_home; source "$DOTFILES_DIR/lib/os.sh"; }
teardown() { teardown_home; }

@test "os_name is macos or linux" {
  run os_name
  [ "$status" -eq 0 ]
  [[ "$output" == "macos" || "$output" == "linux" ]]
}

@test "os_arch is arm64 or x86_64" {
  run os_arch
  [[ "$output" == "arm64" || "$output" == "x86_64" ]]
}

@test "brew_prefix is a known path" {
  run brew_prefix
  [[ "$output" == "/opt/homebrew" || "$output" == "/usr/local" || "$output" == "$HOME/.brew" ]]
}

@test "brew_prefix is the default on macos and the user's home on linux" {
  os_name() { echo macos; }; os_arch() { echo arm64; }
  [ "$(brew_prefix)" = /opt/homebrew ]
  os_name() { echo linux; }; os_arch() { echo x86_64; }
  [ "$(brew_prefix)" = "$HOME/.brew" ]
}
