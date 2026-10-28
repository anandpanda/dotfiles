load helper
G="modules/git"
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  # Copy the module config (not link) so tests never write into the repo.
  link_tree "$DOTFILES_DIR/$G/home" "$HOME" >/dev/null
  mkdir -p "$HOME/.config/git"; cp -R "$DOTFILES_DIR/$G/config/." "$HOME/.config/git/"
  export XDG_STATE_HOME="$HOME/.local/state"
  printf '[user]\n  name = W\n  email = w@work\n  signingkey = ~/.ssh/id_ed25519_work.pub\n' > "$HOME/.config/git/identity.work"
  mkdir -p "$HOME/work/r" "$HOME/personal/r" "$HOME/elsewhere/r"
  for d in work personal elsewhere; do git -C "$HOME/$d/r" init -q; done
  export GIT_CONFIG_NOSYSTEM=1
}
teardown() { teardown_home; }

@test "work tree gets work identity" {
  [ "$(git -C "$HOME/work/r" config user.email)" = "w@work" ]
}

@test "personal tree gets personal identity" {
  run git -C "$HOME/personal/r" config user.email
  [ "$status" -eq 0 ]; [ -n "$output" ]
}

@test "elsewhere has no identity and commit fails" {
  cd "$HOME/elsewhere/r" && touch f && git add f
  run git -c commit.gpgsign=false commit -qm "feat: x"
  [ "$status" -ne 0 ]
}

@test "personal tree rewrites github urls to personal alias" {
  cd "$HOME/personal/r" && git remote add o git@github.com:x/y.git
  run git -C "$HOME/personal/r" ls-remote --get-url o
  [ "$output" = "git@github.com-personal:x/y.git" ]
}

# ---- phase 4 ----
@test "gitconfig parses and carries the modern defaults" {
  run git config --global --list
  [ "$status" -eq 0 ]
  for k in branch.sort=-committerdate column.ui=auto diff.algorithm=histogram push.autosetupremote=true fetch.prune=true rerere.enabled=true rebase.updaterefs=true merge.conflictstyle=zdiff3 pull.rebase=true core.pager=delta gpg.format=ssh commit.gpgsign=true; do
    [[ "$output" == *"$k"* ]] || { echo "missing $k"; false; }
  done
}

@test "every alias resolves and pushf is force-with-lease" {
  for a in st co sw br ci amend undo wip lg lga pushf dft rank; do
    v="$(git config --global --get "alias.$a")"; [ -n "$v" ] || { echo "no alias $a"; false; }
  done
  [[ "$(git config --global --get alias.pushf)" == *force-with-lease* ]]
  [[ "$(git config --global --get alias.pushf)" != *"--force "* ]]
}

@test "commit-msg hook accepts conventional, merge, fixup, revert, multi-line" {
  h="$HOME/.config/git/hooks/commit-msg"
  for m in "feat: add x" "fix(api)!: y" "Merge branch 'x' into main" "fixup! feat: add x" "squash! feat: add x" 'Revert "feat: add x"' $'docs: readme\n\nlonger body\nwith lines'; do
    printf '%s\n' "$m" > "$HOME/msg"; run bash "$h" "$HOME/msg"
    [ "$status" -eq 0 ] || { echo "rejected: $m"; false; }
  done
}

@test "commit-msg hook rejects non-conventional messages with the rule" {
  h="$HOME/.config/git/hooks/commit-msg"
  for m in "update stuff" "Feat: x" "feat:x" ""; do
    printf '%s\n' "$m" > "$HOME/msg"; run bash "$h" "$HOME/msg"
    [ "$status" -ne 0 ] || { echo "accepted: $m"; false; }
    [[ "$output" == *"type(scope): description"* ]]
  done
  printf '# only a comment\n' > "$HOME/msg"; run bash "$h" "$HOME/msg"; [ "$status" -ne 0 ]
}

@test "hooks path is wired so git runs the hook" {
  cd "$HOME/personal/r" && touch f && git add f
  run git -c commit.gpgsign=false commit -qm "bad message"
  [ "$status" -ne 0 ]
  run git -c commit.gpgsign=false commit -qm "feat: good"
  [ "$status" -eq 0 ]
}

@test "install writes allowed_signers from present keys only, no blank lines, idempotent" {
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]
  f="$HOME/.local/state/git/allowed_signers"; [ -f "$f" ]
  [ "$(grep -c . "$f")" = 1 ]; [ "$(wc -l < "$f" | tr -d ' ')" = 1 ]
  grep -q "^anand612p@gmail.com namespaces=\"git\" ssh-ed25519 " "$f"
  ssh-keygen -q -t ed25519 -N "" -C w -f "$HOME/.ssh/id_ed25519_work"
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  [ "$(grep -c . "$f")" = 2 ]; grep -q "^w@work " "$f"
  before="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"; sleep 1
  run bash "$DOTFILES_DIR/$G/install.sh"; [[ "$output" == *"skip"* ]]
  [ "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")" = "$before" ]
}

@test "install dry run writes nothing" {
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  DRY_RUN=1 run bash "$DOTFILES_DIR/$G/install.sh"
  [[ "$output" == *"[dry]"* ]]; [ ! -f "$HOME/.local/state/git/allowed_signers" ]
}

@test "a personal commit is ssh-signed and verifies locally" {
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  cd "$HOME/personal/r" && touch f && git add f && git commit -qm "feat: signed"
  run git log -1 --show-signature
  [[ "$output" == *"Good \"git\" signature"* ]]
}

@test "doctor reports a missing signing key and a stale allowed_signers" {
  run bash "$DOTFILES_DIR/$G/doctor.sh"
  [ "$status" -ne 0 ]; [[ "$output" == *"signing key"*"id_ed25519_personal.pub"* ]]
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  ssh-keygen -q -t ed25519 -N "" -C w -f "$HOME/.ssh/id_ed25519_work"
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  run bash "$DOTFILES_DIR/$G/doctor.sh"; [ "$status" -eq 0 ]
  echo "x y z" >> "$HOME/.local/state/git/allowed_signers"
  run bash "$DOTFILES_DIR/$G/doctor.sh"; [ "$status" -ne 0 ]; [[ "$output" == *"allowed_signers"* ]]
}

@test "shell.zsh parses; gwt creates a sibling worktree and gwtl lists it" {
  zsh -n "$DOTFILES_DIR/$G/shell.zsh"
  cd "$HOME/personal/r" && touch f && git add f && git -c commit.gpgsign=false commit -qm "feat: base"
  run zsh -c "source '$DOTFILES_DIR/$G/shell.zsh'; cd '$HOME/personal/r'; gwt feature-x >/dev/null; pwd; gwtl"
  [[ "$output" == *"$HOME/personal/r-feature-x"* ]]
  [ -d "$HOME/personal/r-feature-x/.git" ] || [ -f "$HOME/personal/r-feature-x/.git" ]
}
