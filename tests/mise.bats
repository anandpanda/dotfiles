load helper
M="modules/mise"
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
}
teardown() { teardown_home; }

fake_mise() { # MISSING-LIST
  cat > "$HOME/bin/mise" <<FAKE
#!/usr/bin/env bash
echo "\$*" >> "\$HOME/mise.log"
case "\$1 \$2" in
  "ls --global") printf '%s\n' "$1" ;;
  "install ") ;;
  "doctor ") echo '{"activated": true, "problems": []}' ;;
esac
FAKE
  chmod +x "$HOME/bin/mise"
}

@test "config lists the global tools and the settings" {
  c="$DOTFILES_DIR/$M/config/config.toml"
  grep -qE '^node = "lts"' "$c"; grep -qE '^python = ' "$c"; grep -qE '^go = ' "$c"; grep -qE '^uv = ' "$c"; grep -qE '^pnpm = ' "$c"
  grep -q 'idiomatic_version_file_enable_tools' "$c"; grep -q 'not_found_auto_install = true' "$c"; grep -q 'uv_venv_auto = ' "$c"
  command -v mise >/dev/null || skip "mise missing"
  run env HOME="$HOME" MISE_GLOBAL_CONFIG_FILE="$c" mise config ls
  [ "$status" -eq 0 ]
}

@test "shell.zsh parses, evaluates activation live, never direnv" {
  zsh -n "$DOTFILES_DIR/$M/shell.zsh"
  grep -q 'eval "$(mise activate zsh)"' "$DOTFILES_DIR/$M/shell.zsh"
  ! grep -qi direnv "$DOTFILES_DIR/$M/shell.zsh"
}

@test "install runs mise install only when tools are missing" {
  fake_mise "node@lts"
  run bash "$DOTFILES_DIR/$M/install.sh"; [ "$status" -eq 0 ]
  grep -q "^install" "$HOME/mise.log"; [[ "$output" == *"installed"* ]]
  fake_mise ""; : > "$HOME/mise.log"
  run bash "$DOTFILES_DIR/$M/install.sh"
  ! grep -q "^install" "$HOME/mise.log"; [[ "$output" == *"skip"* ]]
}

@test "install dry run and no mise are harmless" {
  fake_mise "node@lts"
  DRY_RUN=1 run bash "$DOTFILES_DIR/$M/install.sh"; [ "$status" -eq 0 ]; [[ "$output" == *"[dry]"* ]]; ! grep -q "^install" "$HOME/mise.log"
  PATH="/usr/bin:/bin" run bash "$DOTFILES_DIR/$M/install.sh"; [ "$status" -eq 0 ]
}

@test "doctor lists removable brew-owned runtimes as a warning, exit 0" {
  fake_mise ""
  cat > "$HOME/bin/brew" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "list --formula") printf 'node\ngo\npyenv\npython@3.14\npython@3.12\njq\n' ;;
  "uses --installed") [ "$3" = "python@3.12" ] && echo "some-dep" ;;
esac
FAKE
  chmod +x "$HOME/bin/brew"
  run bash "$DOTFILES_DIR/$M/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew-owned"*"node"* ]] && [[ "$output" == *"go"* ]] && [[ "$output" == *"pyenv"* ]] && [[ "$output" == *"python@3.14"* ]]
  [[ "$output" != *"python@3.12"* ]]
  [[ "$output" != *"jq"* ]]
}

@test "doctor fails when mise doctor reports problems" {
  printf '#!/usr/bin/env bash\n[ "$1" = doctor ] && echo "{\"activated\": true, \"problems\": [\"x\"]}"; exit 0\n' > "$HOME/bin/mise"; chmod +x "$HOME/bin/mise"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/brew"; chmod +x "$HOME/bin/brew"
  run bash "$DOTFILES_DIR/$M/doctor.sh"; [ "$status" -ne 0 ]
}

@test "a project .nvmrc is honoured through mise" {
  command -v mise >/dev/null || skip "mise missing"
  mkdir -p "$HOME/proj"; echo "20" > "$HOME/proj/.nvmrc"
  run env HOME="$HOME" MISE_GLOBAL_CONFIG_FILE="$DOTFILES_DIR/$M/config/config.toml" bash -c "cd '$HOME/proj' && mise ls --current node 2>/dev/null; mise current node"
  [[ "$output" == *20* ]]
}

# ---- review fixes ----
@test "shell.zsh does not cache a frozen PATH: PATH entries added before mise survive" {
  ! grep -q 'zcache mise' "$DOTFILES_DIR/$M/shell.zsh"
  command -v mise >/dev/null || skip "mise missing"
  got="$(zsh -c "export PATH=/first/entry:\$PATH; source '$DOTFILES_DIR/$M/shell.zsh' 2>/dev/null; print -r -- \$PATH" 2>/dev/null | tail -1)"
  [[ "$got" == /first/entry:* ]]
}

@test "doctor: mise not activated is a warning, not a problem" {
  cat > "$HOME/bin/mise" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  doctor) echo '{"activated": false, "problems": []}' ;;
  ls) ;;
esac
FAKE
  chmod +x "$HOME/bin/mise"; printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/brew"; chmod +x "$HOME/bin/brew"
  run bash "$DOTFILES_DIR/$M/doctor.sh"; [ "$status" -eq 0 ]; [[ "$output" == *"not activated"* ]]
  cat > "$HOME/bin/mise" <<'FAKE'
#!/usr/bin/env bash
case "$1" in doctor) echo '{"activated": true, "problems": ["bad thing"]}' ;; esac
FAKE
  run bash "$DOTFILES_DIR/$M/doctor.sh"; [ "$status" -ne 0 ]; [[ "$output" == *"bad thing"* ]]
}

@test "doctor flags brew-owned uv, pnpm, node@, go@ and a go.dev install" {
  printf '#!/usr/bin/env bash\ncase "$1" in doctor) echo "{\\"activated\\": true, \\"problems\\": []}";; esac\n' > "$HOME/bin/mise"; chmod +x "$HOME/bin/mise"
  cat > "$HOME/bin/brew" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in "list --formula") printf 'uv\npnpm\nnode@22\ngo@1.22\njq\n' ;; esac
FAKE
  chmod +x "$HOME/bin/brew"; mkdir -p "$HOME/usr-local-go/bin"; touch "$HOME/usr-local-go/bin/go"; chmod +x "$HOME/usr-local-go/bin/go"
  DOTFILES_GO_DEV="$HOME/usr-local-go" run bash "$DOTFILES_DIR/$M/doctor.sh"
  for t in uv pnpm node@22 go@1.22; do [[ "$output" == *"$t"* ]] || { echo "missing $t"; false; }; done
  [[ "$output" == *"go.dev"* ]]; [[ "$output" != *jq* ]]
}

@test "install and doctor use the global tool list, not the current project's" {
  grep -q 'ls --global --missing' "$DOTFILES_DIR/$M/install.sh"
  grep -q 'ls --global --missing' "$DOTFILES_DIR/$M/doctor.sh"
  cat > "$HOME/bin/mise" <<'FAKE'
#!/usr/bin/env bash
[ "$1 $2" = "ls --global" ] || { echo "wrong args: $*" >&2; exit 2; }
exit 1
FAKE
  chmod +x "$HOME/bin/mise"
  run bash "$DOTFILES_DIR/$M/install.sh"; [ "$status" -ne 0 ]; [[ "$output" != *skip* ]]
}

@test "config: venv auto in the supported form, no auto-prune of old runtimes" {
  c="$DOTFILES_DIR/$M/config/config.toml"
  grep -q 'uv_venv_auto = "create|source"' "$c"
  grep -q 'auto_prune = false' "$c"
  ! grep -qi "install on cd" "$c"
}

@test "secrets example in the README is the form mise accepts" {
  command -v mise >/dev/null || skip "mise missing"
  mkdir -p "$HOME/.secrets" "$HOME/proj"; printf 'tok123\n' > "$HOME/.secrets/github_token"
  sed -n '/^    \[env\]/,/^$/p' "$DOTFILES_DIR/$M/README.md" | sed 's/^    //' > "$HOME/proj/mise.toml"
  grep -q "read_file" "$HOME/proj/mise.toml"
  run env HOME="$HOME" MISE_GLOBAL_CONFIG_FILE="$DOTFILES_DIR/$M/config/config.toml" bash -c "cd '$HOME/proj' && mise trust -q . && mise env -s bash 2>&1"
  [ "$status" -eq 0 ]; [[ "$output" == *"GITHUB_TOKEN=tok123"* ]]
}

@test "mise.local.toml is globally gitignored" {
  grep -qx 'mise.local.toml' "$DOTFILES_DIR/modules/git/config/ignore"
}

@test "doctor lists /etc/paths.d entries whose directories do not exist" {
  printf '#!/usr/bin/env bash\ncase "$1" in doctor) echo "{\\"activated\\": true, \\"problems\\": []}";; esac\n' > "$HOME/bin/mise"; printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/brew"; chmod +x "$HOME/bin/mise" "$HOME/bin/brew"
  mkdir -p "$HOME/paths.d" "$HOME/exists"; echo "/does/not/exist/bin" > "$HOME/paths.d/10-stale"; echo "$HOME/exists" > "$HOME/paths.d/20-ok"
  DOTFILES_PATHS_D="$HOME/paths.d" run bash "$DOTFILES_DIR/$M/doctor.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"10-stale"*"/does/not/exist/bin"* ]]; [[ "$output" != *"20-ok"* ]]
}
