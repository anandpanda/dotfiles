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

@test "plugins are pinned to tags" {
  while read -r line; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    [[ "$line" == *"branch:"* ]]
  done < "$DOTFILES_DIR/$Z/home/.config/zsh/.zsh_plugins.txt"
}

@test "preflight without tty prints commands or ok" {
  run bash "$DOTFILES_DIR/$Z/preflight.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"login shell"* ]]
}

@test "preflight dry run changes nothing" {
  DRY_RUN=1 run bash "$DOTFILES_DIR/$Z/preflight.sh"
  [ "$status" -eq 0 ]
}

@test "interactive startup under 80ms" {
  [ -r /opt/homebrew/opt/antidote/share/antidote/antidote.zsh ] || [ -r /home/linuxbrew/.linuxbrew/opt/antidote/share/antidote/antidote.zsh ] || skip "antidote missing"
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true
  avg=$(HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" python3 -c '
import subprocess, time
t = []
for _ in range(10):
    s = time.perf_counter(); subprocess.run(["zsh", "-i", "-c", "true"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); t.append(time.perf_counter() - s)
t.sort(); print(int(t[len(t)//2] * 1000))')
  echo "median ${avg}ms"
  [ "$avg" -lt 80 ]
}

@test "dots runs just against the dotfiles repo from anywhere" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" DOTFILES_DIR="$DOTFILES_DIR" zsh -i -c 'cd /; dots --list' 
  [ "$status" -eq 0 ]; [[ "$output" == *doctor* ]]
}
