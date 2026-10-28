load helper
# Full-stack startup budget: zsh + cli + starship + atuin shell integration.
# Minimum of 10 runs: machine load can only inflate a run, never hide a slow config.
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state" ANTIDOTE_HOME="$HOME/.cache/antidote"
}
teardown() { teardown_home; }

@test "full stack interactive startup under 80ms" {
  if [ "$(uname -s)" = Darwin ] && pmset -g 2>/dev/null | grep -q "lowpowermode *1"; then skip "Low Power Mode throttles the CPU; measure on full power"; fi
  for t in starship atuin fzf zoxide eza bat; do command -v $t >/dev/null || skip "$t missing"; done
  [ -r /opt/homebrew/opt/antidote/share/antidote/antidote.zsh ] || [ -r /home/linuxbrew/.linuxbrew/opt/antidote/share/antidote/antidote.zsh ] || skip "antidote missing"
  for m in cli zsh starship atuin; do module_apply "$DOTFILES_DIR/modules/$m" >/dev/null; done
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true 2>/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'echo "${PROMPT:+S}${+functions[_atuin_search]}${+functions[__zoxide_z]}${+functions[fzf-file-widget]}"; [[ $PROMPT == *starship* ]] && echo PROMPT-OK'
  [[ "$output" == *S111* ]]
  [[ "$output" == *PROMPT-OK* ]]
  med=$(HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" python3 -c '
import subprocess, time
t = []
for _ in range(10):
    s = time.perf_counter(); subprocess.run(["zsh", "-i", "-c", "true"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); t.append(time.perf_counter() - s)
t.sort(); print(int(t[0] * 1000))')
  echo "min ${med}ms"
  [ "$med" -lt 80 ]
}
