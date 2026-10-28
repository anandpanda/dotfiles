load helper
setup() {
  setup_home
  export DOTFILES_PROFILES="$HOME/profiles"; mkdir -p "$DOTFILES_PROFILES"
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES/one"
  printf 'modules = ["one"]\n' > "$DOTFILES_PROFILES/test.toml"
  export DOTFILES_SKIP_BREW=1
}
teardown() { teardown_home; }

@test "dry run applies nothing and remembers nothing" {
  run "$DOTFILES_DIR/install.sh" test --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.config/dotfiles/profile" ]
}

@test "install applies module and remembers profile" {
  mkdir -p "$DOTFILES_MODULES/one/config"; touch "$DOTFILES_MODULES/one/config/x"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/one" ]
  [ "$(cat "$HOME/.config/dotfiles/profile")" = "test" ]
}

@test "second run is a no-op" {
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [[ "$output" != *"link "* ]]
  [[ "$output" != *"backup"* ]]
}

@test "profile defaults to remembered then personal" {
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/install.sh"
  [[ "$output" == *"profile: test"* ]]
}

@test "unknown module in profile fails" {
  printf 'modules = ["ghost"]\n' > "$DOTFILES_PROFILES/bad.toml"
  run "$DOTFILES_DIR/install.sh" bad
  [ "$status" -ne 0 ]
}

@test "workspace and secrets modules create dirs and report manifest" {
  unset DOTFILES_MODULES
  printf 'modules = ["workspace", "secrets"]\n' > "$DOTFILES_PROFILES/ws.toml"
  run "$DOTFILES_DIR/install.sh" ws
  [ "$status" -eq 0 ]
  [ -d "$HOME/work" ] && [ -d "$HOME/personal" ]
  [ "$(stat -c %a "$HOME/.secrets" 2>/dev/null || stat -f %Lp "$HOME/.secrets")" = "700" ]
  [[ "$output" == *"github_token"* ]]
}

@test "non-tty skips guided steps" {
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  run "$DOTFILES_DIR/install.sh" w
  [ "$status" -eq 0 ]
  [[ "$output" == *"no overlay url"* ]]
}

@test "unknown profile fails and remembers nothing" {
  run "$DOTFILES_DIR/install.sh" persnal
  [ "$status" -ne 0 ]
  [ ! -f "$HOME/.config/dotfiles/profile" ]
}

@test "profile cycle fails" {
  printf 'extends = "b"\n' > "$DOTFILES_PROFILES/a.toml"; printf 'extends = "a"\n' > "$DOTFILES_PROFILES/b.toml"
  run "$DOTFILES_DIR/install.sh" a
  [ "$status" -ne 0 ]
}

@test "--overlay without a value gives a usage error" {
  run "$DOTFILES_DIR/install.sh" test --overlay
  [ "$status" -ne 0 ]
  [[ "$output" == *"--overlay needs a url"* ]]
}

@test "checkout path with spaces works" {
  SP="$HOME/with space"; mkdir -p "$SP"; cp -R "$DOTFILES_DIR"/. "$SP/"
  export DOTFILES_MODULES="$SP/modules" DOTFILES_PROFILES="$SP/profiles"
  run "$SP/install.sh" personal
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/git")" = "$SP/modules/git/config" ]
}

@test "preflight runs after packages and before modules" {
  mkdir -p "$DOTFILES_MODULES/one"
  printf '#!/usr/bin/env bash\necho PREFLIGHT\n' > "$DOTFILES_MODULES/one/preflight.sh"
  printf '#!/usr/bin/env bash\necho INSTALL\n' > "$DOTFILES_MODULES/one/install.sh"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [[ "$output" == *"PREFLIGHT"*"INSTALL"* ]]
  [[ "$output" == *"anything that needs you"*"PREFLIGHT"* ]]
}
