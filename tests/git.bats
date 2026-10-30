load helper
G="modules/git"
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  # Copy the module config (not link) so tests never write into the repo. -L dereferences:
  # identity.work in the repo is itself a link into the overlay checkout, and a plain
  # copy of that link would let the write below land in the real overlay.
  link_tree "$DOTFILES_DIR/$G/home" "$HOME" >/dev/null
  mkdir -p "$HOME/.config/git"; cp -RL "$DOTFILES_DIR/$G/config/." "$HOME/.config/git/"
  [ ! -L "$HOME/.config/git/identity.work" ] || { echo "identity.work is still a link"; return 1; }
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
  for k in branch.sort=-committerdate column.ui=auto diff.algorithm=histogram push.autosetupremote=true fetch.prune=true rerere.enabled=true rebase.updaterefs=true merge.conflictstyle=zdiff3 pull.rebase=true core.pager=delta gpg.format=ssh init.templatedir=; do
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
  h="$HOME/.config/git/template/hooks/commit-msg"
  for m in "feat: add x" "fix(api)!: y" "Merge branch 'x' into main" "fixup! feat: add x" "squash! feat: add x" 'Revert "feat: add x"' $'docs: readme\n\nlonger body\nwith lines'; do
    printf '%s\n' "$m" > "$HOME/msg"; run bash "$h" "$HOME/msg"
    [ "$status" -eq 0 ] || { echo "rejected: $m"; false; }
  done
}

@test "commit-msg hook rejects non-conventional messages with the rule" {
  h="$HOME/.config/git/template/hooks/commit-msg"
  for m in "update stuff" "Feat: x" "feat:x" ""; do
    printf '%s\n' "$m" > "$HOME/msg"; run bash "$h" "$HOME/msg"
    [ "$status" -ne 0 ] || { echo "accepted: $m"; false; }
    [[ "$output" == *"type(scope): description"* ]]
  done
  printf '# only a comment\n' > "$HOME/msg"; run bash "$h" "$HOME/msg"; [ "$status" -ne 0 ]
}

@test "re-running git init in an existing repo installs the hook" {
  cd "$HOME/personal/r" && git init -q && touch f && git add f
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
  touch -r "$f" "$BATS_TEST_TMPDIR/ref"; sleep 1
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]
  case "$output" in *skip*) ;; *) false ;; esac
  [ ! "$f" -nt "$BATS_TEST_TMPDIR/ref" ]
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

@test "doctor warns on a missing signing key and fails on a stale allowed_signers" {
  run bash "$DOTFILES_DIR/$G/doctor.sh"
  [[ "$output" == *"signing key missing"*"id_ed25519_personal.pub"* ]]
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

# ---- review fixes ----
@test "signing is scoped to identities: a repo outside ~/personal and ~/work commits with a local email" {
  cd "$HOME/elsewhere/r" && touch f && git add f
  run git -c user.email=x@y -c user.name=x commit -qm "feat: outside"
  [ "$status" -eq 0 ]
  [ "$(git config --global --get commit.gpgsign || true)" = "" ]
  [ "$(git config --global --get tag.gpgsign || true)" = "" ]
  grep -q "gpgsign = true" "$HOME/.config/git/identity.personal"
}

@test "lightweight tags stay lightweight" {
  cd "$HOME/personal/r" && touch f && git add f && git -c commit.gpgsign=false commit -qm "feat: base"
  run git tag v0; [ "$status" -eq 0 ]
  [ "$(git cat-file -t v0)" = "commit" ]
}

@test "repo hooks still run: no global hooksPath; commit-msg comes from the template dir" {
  [ "$(git config --global --get core.hooksPath || true)" = "" ]
  [ -n "$(git config --global --get init.templateDir)" ]
  mkdir -p "$HOME/personal/new" && git -C "$HOME/personal/new" init -q
  [ -x "$HOME/personal/new/.git/hooks/commit-msg" ]
  cd "$HOME/personal/new" && touch f && git add f
  run git -c commit.gpgsign=false commit -qm "bad"; [ "$status" -ne 0 ]
  printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  run git -c commit.gpgsign=false commit -qm "feat: blocked by repo hook"; [ "$status" -ne 0 ]
}

@test "pushf is force-with-lease and force-if-includes" {
  v="$(git config --global --get alias.pushf)"
  [[ "$v" == *force-with-lease* ]] && [[ "$v" == *force-if-includes* ]]
}

@test "wip alias passes the hook" {
  cd "$HOME/personal/r" && git init -q && echo x > f
  run git -c commit.gpgsign=false wip; [ "$status" -eq 0 ]
  [[ "$(git log -1 --format=%s)" == chore:* ]]
}

@test "gwt tracks an existing remote branch instead of creating a new one" {
  R="$HOME/remote.git"; git init -q --bare "$R"
  cd "$HOME/personal/r" && touch f && git add f && git -c commit.gpgsign=false commit -qm "feat: base" && git remote add origin "$R" && git push -q origin HEAD:main
  git -c commit.gpgsign=false checkout -qb feature-y && echo c > c && git add c && git -c commit.gpgsign=false commit -qm "feat: colleague" && git push -q origin feature-y && git checkout -q - && git branch -qD feature-y
  run zsh -c "source '$DOTFILES_DIR/$G/shell.zsh'; cd '$HOME/personal/r'; gwt feature-y >/dev/null; git log -1 --format=%s; git rev-parse --abbrev-ref --symbolic-full-name @{u}"
  [ "$status" -eq 0 ]; [[ "$output" == *"feat: colleague"* ]]; [[ "$output" == *"origin/feature-y"* ]]
}

@test "hook accepts version-bump messages and ignores leading blank lines" {
  h="$HOME/.config/git/template/hooks/commit-msg"
  printf '1.2.3\n' > "$HOME/msg"; run bash "$h" "$HOME/msg"; [ "$status" -eq 0 ]
  printf '\n\nfeat: after blanks\n' > "$HOME/msg"; run bash "$h" "$HOME/msg"; [ "$status" -eq 0 ]
}

@test "doctor fails when allowed_signers is missing but a key exists" {
  mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C p -f "$HOME/.ssh/id_ed25519_personal"
  run bash "$DOTFILES_DIR/$G/doctor.sh"; [ "$status" -ne 0 ]; [[ "$output" == *"allowed_signers"* ]]
}

@test "pruneTags is off and fetch.all is off" {
  [ "$(git config --global --get fetch.pruneTags || true)" = "" ]
  [ "$(git config --global --get fetch.all || true)" = "" ]
}

@test "install puts the hook into existing repos under ~/work and ~/personal; doctor reports ones without it" {
  mkdir -p "$HOME/work/old/.git/hooks" "$HOME/personal/old2" "$HOME/elsewhere/old3"
  git -C "$HOME/work/old" init -q 2>/dev/null; git -C "$HOME/personal/old2" init -q; git -C "$HOME/elsewhere/old3" init -q
  command rm -f "$HOME/work/old/.git/hooks/commit-msg" "$HOME/personal/old2/.git/hooks/commit-msg" "$HOME/elsewhere/old3/.git/hooks/commit-msg"
  run bash "$DOTFILES_DIR/$G/doctor.sh"; [[ "$output" == *"without commit-msg hook"*"old"* ]]
  run bash "$DOTFILES_DIR/$G/install.sh"; [ "$status" -eq 0 ]
  [[ "$output" == *"hook -> "*"work/old"* ]]
  [ -x "$HOME/work/old/.git/hooks/commit-msg" ]; [ -x "$HOME/personal/old2/.git/hooks/commit-msg" ]
  [ ! -e "$HOME/elsewhere/old3/.git/hooks/commit-msg" ]
  printf '#!/bin/sh\necho custom\n' > "$HOME/work/old/.git/hooks/commit-msg"
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  grep -q custom "$HOME/work/old/.git/hooks/commit-msg"
}

@test "identity files rewrite every GitHub url form to the context's ssh alias" {
  for f in "$DOTFILES_DIR/modules/git/config/identity.personal" "$DOTFILES_DIR/overlays/work.example/modules/git/config/identity.work"; do
    for form in 'git@github.com:' 'https://github.com/' 'ssh://git@github.com/'; do
      grep -qF "insteadOf = $form" "$f" || { echo "$f lacks $form"; false; }
    done
  done
}
