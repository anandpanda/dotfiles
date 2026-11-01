load helper
bats_require_minimum_version 1.5.0
setup() {
  setup_home
  for f in log os link profile module brew preflight ssh overlay; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export DOTFILES_SKIP_BREW=1
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES"; cp -R "$DOTFILES_DIR/modules/git" "$DOTFILES_MODULES/git"
  export DOTFILES_PROFILES="$HOME/profiles" DOTFILES_PROFILE=g; mkdir -p "$DOTFILES_PROFILES"; printf 'modules = ["git"]\n' > "$DOTFILES_PROFILES/g.toml"
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$REMOTE/modules/extra/config"; touch "$REMOTE/modules/extra/config/x"
  git -C "$REMOTE" add -A && git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm extra
}
teardown() { teardown_home; }

@test "overlay_resolve_url prefers argument, then recall, else the default ssh alias url" {
  [ "$(overlay_resolve_url "u1")" = "u1" ]
  remember overlay "u2"
  [ "$(overlay_resolve_url "")" = "u2" ]
  rm "$HOME/.config/dotfiles/overlay"
  [ "$(overlay_resolve_url "")" = "$(overlay_default_url)" ]
}

@test "the default overlay url takes its owner from this repo's origin, in any GitHub url form" {
  real="$DOTFILES_DIR"
  DOTFILES_DIR="$HOME/fake-repo"; git init -q "$DOTFILES_DIR"
  for origin in git@github.com:someone/dotfiles.git https://github.com/someone/dotfiles ssh://git@github.com/someone/dotfiles.git git@github.com-personal:someone/dotfiles.git; do
    git -C "$DOTFILES_DIR" remote remove origin 2>/dev/null || true
    git -C "$DOTFILES_DIR" remote add origin "$origin"
    [ "$(overlay_default_url)" = "git@github.com-personal:someone/dotfiles-work.git" ] || { echo "$origin -> $(overlay_default_url)"; false; }
  done
  DOTFILES_DIR="$real"
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

@test "dry run does not clone" {
  DRY_RUN=1 run overlay_apply "$REMOTE"
  [ ! -d "$HOME/personal/dotfiles-work" ]
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

@test "overlay clone and pull ignore the machine's global git config" {
  printf '[url "%s/nowhere"]\n    insteadOf = %s\n' "$HOME" "$REMOTE" > "$HOME/.gitconfig"
  run git clone -q "$REMOTE" "$HOME/control"
  [ "$status" -ne 0 ]
  run overlay_apply "$REMOTE"
  [ "$status" -eq 0 ]; [ -d "$HOME/personal/dotfiles-work/.git" ]
  run overlay_apply "$REMOTE"
  [ "$status" -eq 0 ]; [[ "$output" == *"pull"* ]]
}

@test "overlay fetch reaches GitHub through the repo's own ssh config, with the url's alias" {
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\necho "$@" > "$HOME/ssh-args"\nexit 1\n' > "$HOME/bin/ssh"; chmod +x "$HOME/bin/ssh"
  PATH="$HOME/bin:$PATH" run overlay_ensure "git@github.com-personal:o/r.git"
  [ "$status" -ne 0 ]
  grep -qF -- "-F $DOTFILES_DIR/modules/ssh/home/.ssh/conf.d/github.conf" "$HOME/ssh-args"
  grep -qF "github.com-personal" "$HOME/ssh-args"; grep -qF "o/r.git" "$HOME/ssh-args"
}

@test "on server-work the workspace makes no personal folder and the overlay checkout creates its own" {
  env -u DOTFILES_PROFILES -u DOTFILES_MODULES DOTFILES_PROFILE=server-work bash "$DOTFILES_DIR/modules/workspace/install.sh" >/dev/null
  [ -d "$HOME/work" ]; [ ! -e "$HOME/personal" ]
  run overlay_apply "$REMOTE"
  [ "$status" -eq 0 ]; [ -d "$HOME/personal/dotfiles-work/.git" ]
}

@test "an existing checkout's origin is set to the resolved url before pulling" {
  overlay_apply "$REMOTE" >/dev/null
  git -C "$HOME/personal/dotfiles-work" remote set-url origin git@github.com:o/r.git
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\necho "$@" > "$HOME/ssh-args"\nexit 1\n' > "$HOME/bin/ssh"; chmod +x "$HOME/bin/ssh"
  PATH="$HOME/bin:$PATH" run overlay_ensure "git@github.com-personal:o/r.git"
  [ "$status" -ne 0 ]
  grep -qF "github.com-personal" "$HOME/ssh-args"
  [ "$(git -C "$HOME/personal/dotfiles-work" remote get-url origin)" = "git@github.com-personal:o/r.git" ]
}
