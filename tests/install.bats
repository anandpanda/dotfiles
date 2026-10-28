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
  # mise resolves home from the user database, not $HOME (2026.10+), so the real one
  # would see this temp home's config as a foreign, untrusted file. Stub it.
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\n' > "$HOME/bin/mise"; chmod +x "$HOME/bin/mise"
  export PATH="$HOME/bin:$PATH"
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

@test "a module install.sh that reads stdin does not swallow later modules" {
  mkdir -p "$DOTFILES_MODULES/one" "$DOTFILES_MODULES/two"
  printf 'modules = ["one", "two"]\n' > "$DOTFILES_PROFILES/t2.toml"
  printf '#!/usr/bin/env bash\ncat >/dev/null; echo ONE\n' > "$DOTFILES_MODULES/one/install.sh"
  printf '#!/usr/bin/env bash\necho TWO\n' > "$DOTFILES_MODULES/two/install.sh"
  run "$DOTFILES_DIR/install.sh" t2
  [[ "$output" == *"ONE"*"TWO"* ]]
}

@test "preflight scripts see the caller's stdin, not the module list" {
  mkdir -p "$DOTFILES_MODULES/one"
  printf '#!/usr/bin/env bash\nread -r x; echo "GOT $x"\n' > "$DOTFILES_MODULES/one/preflight.sh"
  run bash -c "echo hello | '$DOTFILES_DIR/install.sh' test"
  [[ "$output" == *"GOT hello"* ]]
}

@test "overlay is fetched before public modules configure (first work install sees overlay lists)" {
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$REMOTE/modules/one"; echo "ovl" > "$REMOTE/modules/one/marker"
  git -C "$REMOTE" add -A; git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm m
  printf '#!/usr/bin/env bash\n[ -f "$HOME/.dotfiles-work/modules/one/marker" ] && echo SAW-OVERLAY\n' > "$DOTFILES_MODULES/one/install.sh"
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  run "$DOTFILES_DIR/install.sh" w --overlay "$REMOTE"
  [ "$status" -eq 0 ]; [[ "$output" == *"SAW-OVERLAY"* ]]
}

@test "git install reruns after the overlay so overlay identities get signers" {
  # Copy of the modules dir: the overlay lays identity.work inside the public git config dir.
  cp -R "$DOTFILES_DIR/modules" "$HOME/mods-copy"; export DOTFILES_MODULES="$HOME/mods-copy"
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C w -f "$HOME/.ssh/id_ed25519_work"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  printf 'modules = ["git"]\n' > "$DOTFILES_PROFILES/g.toml"; printf 'extends = "g"\noverlay = true\n' > "$DOTFILES_PROFILES/gw.toml"
  run "$DOTFILES_DIR/install.sh" gw --overlay "$REMOTE"
  [ "$status" -eq 0 ]
  grep -q "you@company.com" "$HOME/.local/state/git/allowed_signers"
}
