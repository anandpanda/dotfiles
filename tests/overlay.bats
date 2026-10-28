load helper
setup() {
  setup_home
  for f in log os link profile module brew overlay; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export DOTFILES_SKIP_BREW=1
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES"; cp -R "$DOTFILES_DIR/modules/git" "$DOTFILES_MODULES/git"
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
  [ -d "$HOME/.dotfiles-work/.git" ]
  [ "$(readlink "$HOME/.config/extra")" = "$HOME/.dotfiles-work/modules/extra/config" ]
  [ -L "$HOME/.config/git" ]
  [ "$(recall overlay)" = "$REMOTE" ]
}

@test "overlay git module lays identity.work inside public git config dir" {
  module_apply "$DOTFILES_MODULES/git" >/dev/null
  overlay_apply "$REMOTE"
  [ "$(readlink "$HOME/.config/git")" = "$DOTFILES_MODULES/git/config" ]
  [ "$(readlink "$HOME/.config/git/identity.work")" = "$HOME/.dotfiles-work/modules/git/config/identity.work" ]
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
  [ ! -d "$HOME/.dotfiles-work" ]
}

@test "overlay_clone_url rewrites github urls to the work alias" {
  [ "$(overlay_clone_url git@github.com:org/repo.git)" = "git@github.com-work:org/repo.git" ]
  [ "$(overlay_clone_url https://github.com/org/repo.git)" = "git@github.com-work:org/repo.git" ]
  [ "$(overlay_clone_url /local/path)" = "/local/path" ]
}
