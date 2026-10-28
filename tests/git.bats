load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  module_apply "$DOTFILES_DIR/modules/git" >/dev/null
  mkdir -p "$HOME/.config/git"
  printf '[user]\n  name = W\n  email = w@work\n' > "$HOME/.config/git/identity.work"
  mkdir -p "$HOME/work/r" "$HOME/personal/r" "$HOME/elsewhere/r"
  for d in work personal elsewhere; do git -C "$HOME/$d/r" init -q; done
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
  run git commit -qm x
  [ "$status" -ne 0 ]
}

@test "personal tree rewrites github urls to personal alias" {
  cd "$HOME/personal/r" && git remote add o git@github.com:x/y.git
  run git -C "$HOME/personal/r" ls-remote --get-url o
  [ "$output" = "git@github.com-personal:x/y.git" ]
}
