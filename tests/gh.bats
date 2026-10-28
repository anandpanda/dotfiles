load helper
GH="modules/gh"
setup() {
  setup_home
  for f in log os link module profile; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
  cat > "$HOME/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/gh.log"
case "$1 $2" in
  "alias list") cat "$HOME/aliases.txt" 2>/dev/null ;;
  "alias set") shift 2; [ "$1" = --clobber ] && shift; printf '%s: %s\n' "$1" "$2" >> "$HOME/aliases.txt" ;;
  "auth status") printf '  ✓ Logged in to github.com account %s (keyring)\n  - Active account: true\n' "$(cat "$HOME/active" 2>/dev/null || echo nobody)" ;;
  "auth switch") shift 2; while [ $# -gt 0 ]; do [ "$1" = --user ] && echo "$2" > "$HOME/active"; shift; done ;;
  "auth login") echo "$(cat "$HOME/next-login" 2>/dev/null || echo newuser)" > "$HOME/active" ;;
esac
FAKE
  chmod +x "$HOME/bin/gh"
}
teardown() { teardown_home; }

@test "install sets each alias once and never re-sets an existing one" {
  run bash "$DOTFILES_DIR/$GH/install.sh"; [ "$status" -eq 0 ]
  n=$(grep -c "^alias set" "$HOME/gh.log"); [ "$n" -ge 5 ]
  grep -q "^pc: pr create" "$HOME/aliases.txt"; grep -q "^pm: pr merge --squash --delete-branch" "$HOME/aliases.txt"
  : > "$HOME/gh.log"
  run bash "$DOTFILES_DIR/$GH/install.sh"
  ! grep -q "^alias set" "$HOME/gh.log"; [[ "$output" == *"skip"* ]]
}

@test "install dry run and no gh are both harmless" {
  DRY_RUN=1 run bash "$DOTFILES_DIR/$GH/install.sh"; [ "$status" -eq 0 ]; [ ! -f "$HOME/aliases.txt" ]
  PATH="/usr/bin:/bin" run bash "$DOTFILES_DIR/$GH/install.sh"; [ "$status" -eq 0 ]
}

@test "preflight without tty prints the login command and continues" {
  DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"gh auth login"* ]]
  [ ! -f "$HOME/.config/dotfiles/gh_personal" ]
}

@test "preflight logs in and remembers the account; rerun asks nothing" {
  echo "me-personal" > "$HOME/next-login"; printf 'y\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ "$(cat "$HOME/.config/dotfiles/gh_personal")" = "me-personal" ]
  : > "$HOME/gh.log"
  DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  ! grep -q "auth login" "$HOME/gh.log"; [[ "$output" == *"ok"* ]]
}

@test "preflight for the work profile handles both accounts" {
  echo "me-personal" > "$HOME/next-login"; printf 'y\ny\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=work run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ -f "$HOME/.config/dotfiles/gh_personal" ]; [ -f "$HOME/.config/dotfiles/gh_work" ]
}

@test "chpwd hook switches account by directory and is silent otherwise" {
  zsh -n "$DOTFILES_DIR/$GH/shell.zsh"
  mkdir -p "$HOME/.config/dotfiles" "$HOME/personal/p" "$HOME/work/w" "$HOME/other"
  echo me-personal > "$HOME/.config/dotfiles/gh_personal"; echo me-work > "$HOME/.config/dotfiles/gh_work"
  echo me-personal > "$HOME/active"
  run zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; _dotfiles_gh_switch; cat '$HOME/active'; cd '$HOME/personal/p'; _dotfiles_gh_switch; cat '$HOME/active'; cd '$HOME/other'; _dotfiles_gh_switch; cat '$HOME/active'"
  [ "$status" -eq 0 ]; [ "$output" = $'me-work\nme-personal\nme-personal' ]
  n=$(grep -c "auth switch" "$HOME/gh.log"); [ "$n" = 2 ]
}

@test "chpwd hook without gh or without account files never errors" {
  mkdir -p "$HOME/work/w"
  run zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; _dotfiles_gh_switch; echo ok"
  [ "$status" -eq 0 ]; [ "${lines[-1]}" = ok ]
  run env PATH=/usr/bin:/bin zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; _dotfiles_gh_switch; echo ok"
  [ "$status" -eq 0 ]; [ "${lines[-1]}" = ok ]
}
