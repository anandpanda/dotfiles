load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export ANTIDOTE_HOME="$HOME/.cache/antidote"
}
teardown() { teardown_home; }
Z="modules/zsh"

@test "zsh files parse" {
  for f in home/.zshenv home/.config/zsh/.zshrc home/.config/zsh/options.zsh home/.config/zsh/aliases.zsh; do
    zsh -n "$DOTFILES_DIR/$Z/$f"
  done
}

@test "zshenv sets ZDOTDIR" {
  run zsh -c "source '$DOTFILES_DIR/$Z/home/.zshenv'; echo \$ZDOTDIR"
  [ "$output" = "$HOME/.config/zsh" ]
}

@test "zshrc sources with empty rc.d" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  [ ! -L "$HOME/.config/zsh" ]
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'echo ok'
  [ "$status" -eq 0 ]; [[ "$output" == *ok* ]]
}

@test "rc.d files are sourced in order" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  mkdir -p "$HOME/.config/zsh/rc.d"
  echo 'echo one' > "$HOME/.config/zsh/rc.d/a.zsh"; echo 'echo two' > "$HOME/.config/zsh/rc.d/b.zsh"
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'true'
  [[ "$output" == *$'one\ntwo'* ]]
}

@test "aliases resolve ls to eza when present" {
  command -v eza >/dev/null || skip "eza missing"
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'alias ls'
  [[ "$output" == *eza* ]]
}

@test "plugins are pinned to commits" {
  n=0
  while read -r line; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    [[ "$line" =~ pin:[0-9a-f]{40} ]]; n=$((n + 1))
  done < "$DOTFILES_DIR/$Z/home/.config/zsh/.zsh_plugins.txt"
  [ "$n" -ge 4 ]
}

@test "antidote moves an existing clone to the pinned commit" {
  [ -r /opt/homebrew/opt/antidote/share/antidote/antidote.zsh ] || skip "antidote missing"
  # Real files, not links, so nothing here can touch the repo.
  mkdir -p "$HOME/.config"; cp -R "$DOTFILES_DIR/$Z/home/.config/zsh" "$HOME/.config/zsh"; cp "$DOTFILES_DIR/$Z/home/.zshenv" "$HOME/.zshenv"
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true 2>/dev/null
  d="$ANTIDOTE_HOME/github.com/zsh-users/zsh-autosuggestions"; [ -d "$d/.git" ]
  want="$(git -C "$d" rev-parse HEAD)"
  git -C "$d" fetch -q --unshallow 2>/dev/null || git -C "$d" fetch -q --depth 5
  git -C "$d" checkout -q "$want~1"
  [ "$(git -C "$d" rev-parse HEAD)" != "$want" ]
  touch "$HOME/.config/zsh/.zsh_plugins.txt"
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true 2>/dev/null
  [ "$(git -C "$d" rev-parse HEAD)" = "$want" ]
}
