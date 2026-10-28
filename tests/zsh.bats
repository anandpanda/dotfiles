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

@test "interactive startup under 80ms" {
  if [ "$(uname -s)" = Darwin ] && pmset -g 2>/dev/null | grep -q "lowpowermode *1"; then skip "Low Power Mode throttles the CPU; measure on full power"; fi
  [ -r /opt/homebrew/opt/antidote/share/antidote/antidote.zsh ] || [ -r /home/linuxbrew/.linuxbrew/opt/antidote/share/antidote/antidote.zsh ] || skip "antidote missing"
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true 2>/dev/null
  ms=$(HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" python3 -c '
import subprocess, time
t = []
for _ in range(10):
    s = time.perf_counter(); subprocess.run(["zsh", "-i", "-c", "true"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); t.append(time.perf_counter() - s)
print(int(min(t) * 1000))')
  echo "min ${ms}ms"
  [ "$ms" -lt 80 ]
}

@test "dots runs just against the dotfiles repo from anywhere" {
  command -v just >/dev/null || skip "just missing"
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" DOTFILES_DIR="$DOTFILES_DIR" zsh -i -c 'cd /; dots --list'
  [ "$status" -eq 0 ]; [[ "$output" == *doctor* ]]
}

@test "aged completion dump is refreshed, not rebuilt every shell" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  # Plain zsh (CI has no terminal), stdin closed, and an insecure dir on fpath like CI
  # runners have: compinit must not stop to ask about it.
  mkdir -p "$HOME/insecure"; chmod 777 "$HOME/insecure"
  # FPATH replaces zsh's whole function path when set, so keep zsh's own dirs on it.
  zfpath="$(zsh -c 'print -r -- ${(j.:.)fpath}')"
  r() { env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" XDG_CACHE_HOME="$HOME/.cache" FPATH="$HOME/insecure:$zfpath" zsh -c 'source "$ZDOTDIR/.zshrc"' </dev/null 2>"$HOME/err" || true; }
  r
  d="$HOME/.cache/zsh/compdump"
  [ -f "$d" ] || { cat "$HOME/err"; false; }
  touch -t 202001010000 "$d"
  r
  [ "$(find "$d" -mmin -5 | wc -l | tr -d ' ')" = 1 ]
}

@test "zcache regenerates when args, filter, or resolved binary change" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  mkdir -p "$HOME/t/v1" "$HOME/t/v2"
  printf '#!/bin/sh\necho "echo V1-$*"\n' > "$HOME/t/v1/tool"; printf '#!/bin/sh\necho "echo V2-$*"\n' > "$HOME/t/v2/tool"; chmod +x "$HOME/t/v1/tool" "$HOME/t/v2/tool"
  ln -s "$HOME/t/v1/tool" "$HOME/tool"
  r() { env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" XDG_CACHE_HOME="$HOME/.cache" PATH="$HOME:$PATH" zsh -c "source \$ZDOTDIR/options.zsh; $1"; }
  [ "$(r 'zcache tool tool a')" = "V1-a" ]
  [ "$(r 'zcache tool tool a')" = "V1-a" ]
  [ "$(r 'zcache tool tool b')" = "V1-b" ]
  [ "$(r 'ZCACHE_FILTER=s/V1/F1/ zcache tool tool b')" = "F1-b" ]
  ln -sfn "$HOME/t/v2/tool" "$HOME/tool"
  [ "$(r 'zcache tool tool b')" = "V2-b" ]
}

@test "HEAD^ is not globbed at the prompt" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'print HEAD^'
  [ "${lines[${#lines[@]}-1]}" = "HEAD^" ]
}

@test "DOTFILES_DIR is derived from the .zshenv symlink" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env -u DOTFILES_DIR HOME="$HOME" zsh -c 'source ~/.zshenv; echo $DOTFILES_DIR'
  [ "$output" = "$(cd "$DOTFILES_DIR" && pwd -P)" ]
}

@test "brew is on PATH in a non-interactive login shell" {
  command -v brew >/dev/null || skip
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" PATH=/usr/bin:/bin zsh -l -c 'command -v brew'
  [[ "$output" == */bin/brew ]]
}

@test "grep and find are not aliased" {
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'alias grep; alias find; echo end'
  [ "${lines[${#lines[@]}-1]}" = "end" ]
  [[ "$output" != *"grep="* ]] && [[ "$output" != *"find="* ]]
}

@test "login shell preflight: a declined switch is remembered and a failed chsh does not abort" {
  [ -x /opt/homebrew/bin/zsh ] || [ -x /home/linuxbrew/.linuxbrew/bin/zsh ] || skip "homebrew zsh not installed"
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\nexit 1\n' > "$HOME/bin/chsh"
  printf '#!/bin/sh\necho "UserShell: /bin/zsh"\n' > "$HOME/bin/dscl"
  printf '#!/bin/sh\necho "u:x:1:1::/home/u:/bin/bash"\n' > "$HOME/bin/getent"
  chmod +x "$HOME/bin/chsh" "$HOME/bin/dscl" "$HOME/bin/getent"
  export PATH="$HOME/bin:$PATH"
  printf 'n\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run bash "$DOTFILES_DIR/$Z/preflight.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"kept"* ]]
  printf 'y\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run bash "$DOTFILES_DIR/$Z/preflight.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"login shell"* ]]; [[ "$output" != *"Switch"* ]]
}

@test "zsh module backs up a pre-existing ~/.zshrc and ~/.zprofile" {
  echo old > "$HOME/.zshrc"; echo old > "$HOME/.zprofile"
  module_apply "$DOTFILES_DIR/$Z" >/dev/null
  [ ! -e "$HOME/.zshrc" ]; [ ! -e "$HOME/.zprofile" ]
  [ "$(find "$HOME/.dotfiles-backup" -name .zshrc | wc -l | tr -d ' ')" = 1 ]
}
