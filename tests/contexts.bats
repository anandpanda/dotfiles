load helper
G="modules/git"
TAB=$'\t'
setup() {
  setup_home
  for f in log os link profile module contexts; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export GIT_CONFIG_NOSYSTEM=1 XDG_STATE_HOME="$HOME/.local/state"
  unset DOTFILES_OVERLAY_DIR DOTFILES_MODULES DOTFILES_PROFILES DOTFILES_PROFILE
  O="$HOME/personal/dotfiles-work"
}
teardown() { teardown_home; }

# Fake public modules a, b in profile p, and an overlay module x.
fake_tree() {
  export DOTFILES_MODULES="$HOME/mods" DOTFILES_PROFILES="$HOME/profiles" DOTFILES_PROFILE=p
  mkdir -p "$DOTFILES_MODULES/a/contexts" "$DOTFILES_MODULES/b/contexts" "$DOTFILES_MODULES/c/contexts" "$DOTFILES_PROFILES" "$O/modules/x/contexts"
  printf 'modules = ["a", "b"]\noverlay = true\n' > "$DOTFILES_PROFILES/p.toml"
  printf 'modules = ["a", "b"]\n' > "$DOTFILES_PROFILES/q.toml"
  printf '# personal roots\n~/personal\n\n' > "$DOTFILES_MODULES/a/contexts/personal"
  printf '~/work/\n' > "$DOTFILES_MODULES/a/contexts/work"
  printf '  ~/work   # again\n' > "$DOTFILES_MODULES/b/contexts/work"
  printf '/not/in/profile\n' > "$DOTFILES_MODULES/c/contexts/work"
  printf '~/company\n~/work\n' > "$O/modules/x/contexts/work"
}

# Real git module in a temp HOME with two identities that differ only by email.
real_git() {
  link_tree "$DOTFILES_DIR/$G/home" "$HOME" >/dev/null
  mkdir -p "$HOME/.config/git"; cp -RL "$DOTFILES_DIR/$G/config/." "$HOME/.config/git/"
  printf '[user]\n  name = P\n  email = p@personal\n' > "$HOME/.config/git/identity.personal"
  printf '[user]\n  name = W\n  email = w@work\n' > "$HOME/.config/git/identity.work"
}
email() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config user.email || true; }

@test "collect merges public and overlay lists, expands ~, ignores comments and dups" {
  fake_tree
  run contexts_collect
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c .)" = 3 ]
  [[ "$output" == *"personal$TAB$HOME/personal"* ]]
  [[ "$output" == *"work$TAB$HOME/work"* ]]
  [[ "$output" == *"work$TAB$HOME/company"* ]]
  [[ "$output" != *"/not/in/profile"* ]]
  [[ "$output" != *"~"* ]]; [[ "$output" != *"#"* ]]
}

@test "collect without an overlay checkout lists only public modules" {
  fake_tree; rm -rf "$O"
  run contexts_collect
  [ "$status" -eq 0 ]; [[ "$output" != *company* ]]; [[ "$output" == *"work$TAB$HOME/work"* ]]
}

@test "collect ignores an overlay checkout when the profile does not use the overlay" {
  fake_tree
  DOTFILES_PROFILE=q run contexts_collect
  [ "$status" -eq 0 ]; [[ "$output" != *company* ]]; [[ "$output" == *"work$TAB$HOME/work"* ]]
  DOTFILES_PROFILE=p run contexts_collect
  [[ "$output" == *"work$TAB$HOME/company"* ]]
}

@test "public defaults are exactly ~/personal and ~/work" {
  DOTFILES_PROFILE=personal run contexts_collect
  [ "$status" -eq 0 ]
  [ "$output" = "work$TAB$HOME/work"$'\n'"personal$TAB$HOME/personal" ]
}

@test "overlay checkout defaults to ~/personal/dotfiles-work, override kept" {
  [ "$(overlay_dir)" = "$HOME/personal/dotfiles-work" ]
  [ "$(DOTFILES_OVERLAY_DIR=/x overlay_dir)" = /x ]
}

@test "collect fails on an unknown profile" {
  DOTFILES_PROFILE=nope run contexts_collect
  [ "$status" -ne 0 ]
}

@test "install writes the state list and one include block per folder" {
  fake_tree; real_git
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]
  [ "$(grep -c . "$HOME/.config/dotfiles/contexts")" = 3 ]
  inc="$HOME/.local/state/git/contexts.inc"
  [ "$(grep -c '^\[includeIf "gitdir:' "$inc")" = 3 ]
  grep -qF "[includeIf \"gitdir:~/company/\"]" "$inc"
  run bash "$DOTFILES_DIR/$G/install.sh"
  [[ "$output" == *"skip $inc"* ]]
}

@test "real git: work, overlay-added work, personal and the overlay checkout get the right email" {
  export DOTFILES_PROFILE=work
  mkdir -p "$O/modules/extra/contexts"; printf '~/company\n~/does-not-exist\n' > "$O/modules/extra/contexts/work"
  git -C "$O" init -q
  real_git
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]
  [ "$(email "$HOME/work/r")" = w@work ]
  [ "$(email "$HOME/company/r")" = w@work ]
  [ "$(email "$HOME/company/deep/er/r")" = w@work ]
  [ "$(email "$HOME/personal/r")" = p@personal ]
  [ "$(git -C "$O" config user.email)" = p@personal ]
  [ "$(email "$HOME/elsewhere/r")" = "" ]
  [ "$(email "$HOME/companyx/r")" = "" ]
}

@test "real git: a personal folder nested in a work folder wins" {
  fake_tree; real_git
  printf '~/company/mine\n' > "$DOTFILES_MODULES/b/contexts/personal"
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  [ "$(email "$HOME/company/mine/r")" = p@personal ]
  [ "$(email "$HOME/company/theirs")" = w@work ]
}

@test "hook install covers an overlay-added folder; doctor reports a hookless repo there" {
  fake_tree; real_git
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  mkdir -p "$HOME/company/old"; git -C "$HOME/company/old" init -q; rm -f "$HOME/company/old/.git/hooks/commit-msg"
  run bash "$DOTFILES_DIR/$G/doctor.sh"
  [[ "$output" == *"without commit-msg hook: $HOME/company/old"* ]]
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]; [ -x "$HOME/company/old/.git/hooks/commit-msg" ]
}

@test "doctor reports a stale contexts include after a list changes" {
  fake_tree; real_git
  bash "$DOTFILES_DIR/$G/install.sh" >/dev/null
  run bash "$DOTFILES_DIR/$G/doctor.sh"; [[ "$output" != *contexts* ]]
  printf '~/more\n' >> "$O/modules/x/contexts/work"
  run bash "$DOTFILES_DIR/$G/doctor.sh"
  [ "$status" -ne 0 ]; [[ "$output" == *"contexts"* ]]
}

@test "install dry run writes no context files" {
  fake_tree; real_git
  DRY_RUN=1 run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"[dry] write $HOME/.local/state/git/contexts.inc"* ]]
  [ ! -e "$HOME/.local/state/git/contexts.inc" ]; [ ! -e "$HOME/.config/dotfiles/contexts" ]
}

@test "a folder listed as both personal and work fails install instead of guessing" {
  fake_tree; real_git
  printf '~/company\n' > "$DOTFILES_MODULES/b/contexts/personal"
  run bash "$DOTFILES_DIR/$G/install.sh"
  [ "$status" -ne 0 ]; [[ "$output" == *"both personal and work"*"$HOME/company"* ]]
}
