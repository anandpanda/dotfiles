load helper
S="modules/shell"
setup() {
  setup_home
  for f in log os link module file; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/.brew/bin"; printf '#!/bin/sh\n' > "$HOME/.brew/bin/brew"; chmod +x "$HOME/.brew/bin/brew"
  want="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.brew/bin:$HOME/.brew/sbin:/usr/bin:/bin"
}
teardown() { teardown_home; }

@test "env.sh from a clean sh or plain zsh puts ~/.local/bin, mise shims and Homebrew first, and twice changes nothing" {
  for sh in "sh -c" "zsh -fc"; do
    run env -i HOME="$HOME" PATH=/usr/bin:/bin $sh ". '$DOTFILES_DIR/$S/config/env.sh'; echo \"\$PATH \$HOMEBREW_PREFIX\"; . '$DOTFILES_DIR/$S/config/env.sh'; echo \"\$PATH\""
    [ "${lines[0]}" = "$want $HOME/.brew" ] || false
    [ "${lines[1]}" = "$want" ] || false
  done
}

@test "the shell module points Claude Code's Bash tool at env.sh" {
  [ "$(jq -r '.env.CLAUDE_ENV_FILE' "$DOTFILES_DIR/$S/claude-settings.json")" = '${HOME}/.config/shell/env.sh' ]
}

@test "install makes env.sh the first line of an existing .bashrc that returns early when not interactive" {
  printf 'case $- in *i*) ;; *) return ;; esac\nalias ll=ls\n' > "$HOME/.bashrc"
  module_apply "$DOTFILES_DIR/$S" >/dev/null
  [ "$(head -1 "$HOME/.bashrc")" = '. "$HOME/.config/shell/env.sh"' ] || false
  grep -qx 'alias ll=ls' "$HOME/.bashrc" || false
  before="$(cksum < "$HOME/.bashrc")"
  module_apply "$DOTFILES_DIR/$S" >/dev/null
  [ "$(cksum < "$HOME/.bashrc")" = "$before" ]
}

@test "bash login, bash interactive and sh login shells all get the same PATH" {
  module_apply "$DOTFILES_DIR/$S" >/dev/null
  ours="${want%:/usr/bin:/bin}:"
  for mode in -lc -ic; do
    run env -i HOME="$HOME" PATH=/usr/bin:/bin bash "$mode" 'echo "$PATH"'
    [[ "${lines[${#lines[@]}-1]}" == "$ours"* ]] || false
  done
  run env -i HOME="$HOME" PATH=/usr/bin:/bin sh -lc 'echo "$PATH"'
  [[ "${lines[${#lines[@]}-1]}" == "$ours"* ]]
}

@test "doctor reports a shell file whose first line does not load env.sh" {
  module_apply "$DOTFILES_DIR/$S" >/dev/null
  run bash "$DOTFILES_DIR/$S/doctor.sh"
  [ "$status" -eq 0 ] || false
  printf 'echo hi\n' > "$HOME/.profile"
  run bash "$DOTFILES_DIR/$S/doctor.sh"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"$HOME/.profile does not load env.sh first"* ]]
}
