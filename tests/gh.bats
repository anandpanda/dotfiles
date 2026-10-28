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
  "auth status") if [ -s "$HOME/active" ]; then printf '  ✓ Logged in to github.com account %s (keyring)\n  - Active account: true\n' "$(cat "$HOME/active")"; else echo "You are not logged into any GitHub hosts." >&2; exit 1; fi ;;
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

@test "preflight for the work profile logs in two different accounts" {
  # The fake logs in as the next name in a queue, one per `auth login`.
  printf 'me-personal\nme-work\n' > "$HOME/login-queue"
  cat > "$HOME/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/gh.log"
case "$1 $2" in
  "auth status") if [ -s "$HOME/active" ]; then printf '  ✓ Logged in to github.com account %s (keyring)\n  - Active account: true\n' "$(cat "$HOME/active")"; else exit 1; fi ;;
  "auth login") head -1 "$HOME/login-queue" > "$HOME/active"; tail -n +2 "$HOME/login-queue" > "$HOME/q.tmp"; mv "$HOME/q.tmp" "$HOME/login-queue" ;;
esac
FAKE
  chmod +x "$HOME/bin/gh"
  printf 'y\ny\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=work run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/dotfiles/gh_personal")" = me-personal ]
  [ "$(cat "$HOME/.config/dotfiles/gh_work")" = me-work ]
}

@test "gh wrapper parses and is harmless without account files or outside the trees" {
  zsh -n "$DOTFILES_DIR/$GH/shell.zsh"
  mkdir -p "$HOME/work/w" "$HOME/other"
  run zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; gh pr list; cd '$HOME/other'; gh pr list; echo ok"
  [ "$status" -eq 0 ]; [[ "$output" == *ok ]]
  ! grep -q "auth switch" "$HOME/gh.log"
}

@test "gh wrapper switches account per directory before every command, across shells" {
  mkdir -p "$HOME/.config/dotfiles" "$HOME/.config/gh" "$HOME/personal/p" "$HOME/work/w"
  echo me-personal > "$HOME/.config/dotfiles/gh_personal"; echo me-work > "$HOME/.config/dotfiles/gh_work"
  printf 'github.com:\n    user: me-personal\n' > "$HOME/.config/gh/hosts.yml"
  cat > "$HOME/bin/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/gh.log"
case "$1 $2" in
  "auth switch") shift 2; while [ $# -gt 0 ]; do [ "$1" = --user ] && printf 'github.com:\n    user: %s\n' "$2" > "$HOME/.config/gh/hosts.yml"; shift; done ;;
  "pr list") grep user: "$HOME/.config/gh/hosts.yml" ;;
esac
FAKE
  chmod +x "$HOME/bin/gh"
  run zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; gh pr list; cd '$HOME/personal/p'; gh pr list"
  [ "$status" -eq 0 ]; [[ "$output" == *"user: me-work"*"user: me-personal"* ]]
  # A second shell that starts in ~/work must switch even though chpwd never fired.
  printf 'github.com:\n    user: me-personal\n' > "$HOME/.config/gh/hosts.yml"
  run zsh -c "cd '$HOME/work/w'; source '$DOTFILES_DIR/$GH/shell.zsh'; gh pr list"
  [[ "$output" == *"user: me-work"* ]]
}

@test "gh wrapper does not call switch when already on the right account" {
  mkdir -p "$HOME/.config/dotfiles" "$HOME/.config/gh" "$HOME/work/w"
  echo me-work > "$HOME/.config/dotfiles/gh_work"; printf 'github.com:\n    user: me-work\n' > "$HOME/.config/gh/hosts.yml"
  run zsh -c "source '$DOTFILES_DIR/$GH/shell.zsh'; cd '$HOME/work/w'; gh pr list; gh pr list"
  ! grep -q "auth switch" "$HOME/gh.log"
}

@test "preflight refuses to remember the work account as the same user as personal" {
  mkdir -p "$HOME/.config/dotfiles"; echo me-personal > "$HOME/.config/dotfiles/gh_personal"
  echo "me-personal" > "$HOME/next-login"; printf 'y\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=work run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ ! -f "$HOME/.config/dotfiles/gh_work" ]; [[ "$output" == *"same account"* ]]
}

@test "install reports a failed alias set" {
  cat > "$HOME/bin/gh" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in "alias list") ;; "alias set") exit 1 ;; esac
FAKE
  chmod +x "$HOME/bin/gh"
  run bash "$DOTFILES_DIR/$GH/install.sh"
  [[ "$output" == *"could not set"* ]]
}

@test "preflight never guesses: with accounts logged in it asks which is personal, and remembers the pick" {
  cat > "$HOME/bin/gh" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") printf '  ✓ Logged in to github.com account work-acct (keyring)\n  - Active account: true\n  ✓ Logged in to github.com account me-personal (keyring)\n  - Active account: false\n' ;;
esac
FAKE
  chmod +x "$HOME/bin/gh"
  # Without a terminal: nothing recorded, instructions printed.
  DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ ! -f "$HOME/.config/dotfiles/gh_personal" ]; [[ "$output" == *"which"* ]]
  # With a terminal: pick the second one by number.
  printf '2\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ "$(cat "$HOME/.config/dotfiles/gh_personal")" = me-personal ]
  # Work profile: the remaining account is offered first; picking it records work.
  printf '1\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=work run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$status" -eq 0 ]; [ "$(cat "$HOME/.config/dotfiles/gh_work")" = work-acct ]
}

@test "preflight with one account logged in still asks before recording it" {
  echo "only-one" > "$HOME/active"
  DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ ! -f "$HOME/.config/dotfiles/gh_personal" ]
  printf '1\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/$GH/preflight.sh"
  [ "$(cat "$HOME/.config/dotfiles/gh_personal")" = only-one ]
}
