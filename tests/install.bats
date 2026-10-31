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
  [[ "$output" != *"missing secrets"* ]]
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
  stub_externals
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
  printf '#!/usr/bin/env bash\n[ -f "$HOME/personal/dotfiles-work/modules/one/marker" ] && echo SAW-OVERLAY\n' > "$DOTFILES_MODULES/one/install.sh"
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

@test "link record: a file dropped from a module loses its link on the next install" {
  mkdir -p "$DOTFILES_MODULES/one/home"; touch "$DOTFILES_MODULES/one/home/.a" "$DOTFILES_MODULES/one/home/.b"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  [ -L "$HOME/.a" ] && [ -L "$HOME/.b" ]
  rm "$DOTFILES_MODULES/one/home/.b"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]; [[ "$output" == *"removed stale link $HOME/.b"* ]]
  [ -L "$HOME/.a" ]; [ ! -L "$HOME/.b" ]
  ! grep -qxF "$HOME/.b" "$HOME/.config/dotfiles/links"
}

@test "link record: a module dropped from the profile has its links removed" {
  mkdir -p "$DOTFILES_MODULES/two/home"; touch "$DOTFILES_MODULES/two/home/.t"
  printf 'modules = ["one", "two"]\n' > "$DOTFILES_PROFILES/t2.toml"
  "$DOTFILES_DIR/install.sh" t2 >/dev/null
  [ -L "$HOME/.t" ]
  "$DOTFILES_DIR/install.sh" test >/dev/null
  [ ! -L "$HOME/.t" ]
}

@test "link record: a recorded link now pointing elsewhere is never removed" {
  mkdir -p "$DOTFILES_MODULES/one/home"; touch "$DOTFILES_MODULES/one/home/.b" "$HOME/mine"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  rm "$DOTFILES_MODULES/one/home/.b"; ln -sfn "$HOME/mine" "$HOME/.b"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  [ "$(readlink "$HOME/.b")" = "$HOME/mine" ]
}

@test "link record: dry run prints the stale link and removes nothing" {
  mkdir -p "$DOTFILES_MODULES/one/home"; touch "$DOTFILES_MODULES/one/home/.b"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  cp "$HOME/.config/dotfiles/links" "$HOME/record-before"
  rm "$DOTFILES_MODULES/one/home/.b"
  run "$DOTFILES_DIR/install.sh" test --dry-run
  [ "$status" -eq 0 ]; [[ "$output" == *"[dry] remove stale link $HOME/.b"* ]]
  [ -L "$HOME/.b" ]; cmp "$HOME/.config/dotfiles/links" "$HOME/record-before"
}

@test "link record: the first run removes nothing" {
  mkdir -p "$DOTFILES_MODULES/one/home" "$DOTFILES_MODULES/one/config"; touch "$DOTFILES_MODULES/one/home/.old" "$DOTFILES_MODULES/one/config/x"
  ln -s "$DOTFILES_MODULES/one/home/.old" "$HOME/.old"; rm "$DOTFILES_MODULES/one/home/.old"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]; [ -L "$HOME/.old" ]
  grep -qxF "$HOME/.config/one" "$HOME/.config/dotfiles/links"
}

@test "link record: links made by a module install.sh are recorded and kept" {
  mkdir -p "$DOTFILES_MODULES/one/files"; touch "$DOTFILES_MODULES/one/files/f"
  printf '#!/usr/bin/env bash\nsource "$DOTFILES_DIR/lib/log.sh"; source "$DOTFILES_DIR/lib/link.sh"\nlink_file "%s" "$HOME/elsewhere/f"\n' "$DOTFILES_MODULES/one/files/f" > "$DOTFILES_MODULES/one/install.sh"
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/install.sh" test
  [[ "$output" != *"removed stale"* ]]; [ -L "$HOME/elsewhere/f" ]
  grep -qxF "$HOME/elsewhere/f" "$HOME/.config/dotfiles/links"
}

@test "link record: a work run that skips the overlay removes no overlay link and keeps the record" {
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$REMOTE/modules/extra/home"; touch "$REMOTE/modules/extra/home/.ovl"
  git -C "$REMOTE" add -A; git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm m
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  "$DOTFILES_DIR/install.sh" w --overlay "$REMOTE" >/dev/null
  [ -L "$HOME/.ovl" ]
  cp "$HOME/.config/dotfiles/links" "$HOME/record-before"
  rm "$HOME/.config/dotfiles/overlay"
  run "$DOTFILES_DIR/install.sh" w
  [ "$status" -eq 0 ]; [[ "$output" == *"no overlay url"* ]]
  [ -L "$HOME/.ovl" ]; cmp "$HOME/.config/dotfiles/links" "$HOME/record-before"
}

@test "dots install without a profile leaves the choice to install.sh" {
  run just --justfile "$DOTFILES_DIR/justfile" --dry-run install
  [ "$status" -eq 0 ]
  case "$output" in *"./install.sh"*) ;; *) false ;; esac
  case "$output" in *personal*) false ;; esac
}

@test "dots install passes a named profile and flags through" {
  run just --justfile "$DOTFILES_DIR/justfile" --dry-run install work --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"./install.sh work --dry-run"* ]]
}
