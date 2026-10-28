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
  "ls --missing") printf '%s\n' "$1" ;;
  "install ") ;;
  "doctor ") exit 0 ;;
esac
FAKE
  chmod +x "$HOME/bin/mise"
}

@test "config lists the global tools and the settings" {
  c="$DOTFILES_DIR/$M/config/config.toml"
  grep -qE '^node = "lts"' "$c"; grep -qE '^python = ' "$c"; grep -qE '^go = ' "$c"; grep -qE '^uv = ' "$c"; grep -qE '^pnpm = ' "$c"
  grep -q 'idiomatic_version_file_enable_tools' "$c"; grep -q 'not_found_auto_install = true' "$c"; grep -q 'uv_venv_auto = true' "$c"
  command -v mise >/dev/null || skip "mise missing"
  run env HOME="$HOME" MISE_GLOBAL_CONFIG_FILE="$c" mise config ls
  [ "$status" -eq 0 ]
}

@test "shell.zsh parses and activates through zcache" {
  zsh -n "$DOTFILES_DIR/$M/shell.zsh"
  grep -q 'zcache mise mise activate zsh' "$DOTFILES_DIR/$M/shell.zsh"
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

@test "doctor fails when mise doctor fails" {
  printf '#!/usr/bin/env bash\n[ "$1" = doctor ] && exit 1; exit 0\n' > "$HOME/bin/mise"; chmod +x "$HOME/bin/mise"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/brew"; chmod +x "$HOME/bin/brew"
  run bash "$DOTFILES_DIR/$M/doctor.sh"; [ "$status" -ne 0 ]
}

@test "a project .nvmrc is honoured through mise" {
  command -v mise >/dev/null || skip "mise missing"
  mkdir -p "$HOME/proj"; echo "20" > "$HOME/proj/.nvmrc"
  run env HOME="$HOME" MISE_GLOBAL_CONFIG_FILE="$DOTFILES_DIR/$M/config/config.toml" bash -c "cd '$HOME/proj' && mise ls --current node 2>/dev/null; mise current node"
  [[ "$output" == *20* ]]
}
