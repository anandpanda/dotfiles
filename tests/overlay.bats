load helper
bats_require_minimum_version 1.5.0
setup() {
  setup_home
  for f in log os link profile module brew preflight overlay; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export DOTFILES_SKIP_BREW=1
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES"; cp -R "$DOTFILES_DIR/modules/git" "$DOTFILES_MODULES/git"
  export DOTFILES_PROFILES="$HOME/profiles" DOTFILES_PROFILE=g; mkdir -p "$DOTFILES_PROFILES"; printf 'modules = ["git"]\n' > "$DOTFILES_PROFILES/g.toml"
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$REMOTE/modules/extra/config"; touch "$REMOTE/modules/extra/config/x"
  git -C "$REMOTE" add -A && git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm extra
}
teardown() { teardown_home; }

@test "overlay_resolve_url prefers argument, then recall, else empty without tty" {
  [ "$(overlay_resolve_url "u1")" = "u1" ]
  remember overlay "u2"
  [ "$(overlay_resolve_url "")" = "u2" ]
  rm "$HOME/.config/dotfiles/overlay"
  [ -z "$(overlay_resolve_url "")" ]
}

@test "overlay_apply clones, applies modules, remembers url" {
  overlay_apply "$REMOTE"
  [ -d "$HOME/personal/dotfiles-work/.git" ]
  [ "$(readlink "$HOME/.config/extra")" = "$HOME/personal/dotfiles-work/modules/extra/config" ]
  [ -L "$HOME/.config/git" ]
  [ "$(recall overlay)" = "$REMOTE" ]
}

@test "overlay git module lays identity.work inside public git config dir" {
  module_apply "$DOTFILES_MODULES/git" >/dev/null
  overlay_apply "$REMOTE"
  [ "$(readlink "$HOME/.config/git")" = "$DOTFILES_MODULES/git/config" ]
  [ "$(readlink "$HOME/.config/git/identity.work")" = "$HOME/personal/dotfiles-work/modules/git/config/identity.work" ]
}

@test "second apply pulls instead of cloning" {
  overlay_apply "$REMOTE"
  run overlay_apply "$REMOTE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull"* ]]
}

@test "no url and no tty warns and returns 0" {
  run overlay_apply ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"no overlay url"* ]]
}

@test "dry run does not clone" {
  DRY_RUN=1 run overlay_apply "$REMOTE"
  [ ! -d "$HOME/personal/dotfiles-work" ]
}

@test "overlay url is cloned exactly as given: the ssh alias in it picks the key" {
  ! grep -q "overlay_clone_url\|github.com-work" "$DOTFILES_DIR/lib/overlay.sh"
  grep -q 'git clone -q "$url"' "$DOTFILES_DIR/lib/overlay.sh"
}

@test "overlay url prompt goes to stderr and reads from the terminal" {
  is_tty() { return 0; }
  echo "git@github.com:o/r.git" > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run --separate-stderr overlay_resolve_url ""
  [ "$output" = "git@github.com:o/r.git" ]
  [[ "$stderr" == *"overlay"* ]]
}

@test "overlay preflight scripts run" {
  mkdir -p "$REMOTE/modules/pf"; printf '#!/usr/bin/env bash\necho OVERLAY-PREFLIGHT\n' > "$REMOTE/modules/pf/preflight.sh"
  git -C "$REMOTE" add -A; git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm pf
  run overlay_apply "$REMOTE"
  [[ "$output" == *"OVERLAY-PREFLIGHT"* ]]
}

@test "overlay-init's own commit passes the Conventional Commits hook our git template installs" {
  run env GIT_TEMPLATE_DIR="$DOTFILES_DIR/modules/git/config/template" "$DOTFILES_DIR/scripts/overlay-init.sh" "$HOME/ov"
  [ "$status" -eq 0 ]
  [ "$(git -C "$HOME/ov" log --format=%s -1)" = "chore: overlay skeleton" ]
  [ -x "$HOME/ov/.git/hooks/commit-msg" ]
}
