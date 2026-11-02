# Read by every zsh, login or not. Points zsh at XDG config; everything else lives there.
export ZDOTDIR="$HOME/.config/zsh"
# Git identity comes from the folder and ssh keys from the ssh config, so drop the
# variables an environment (a Coder template) injects to override them.
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_SSH_COMMAND
# The repo root, found through this file's own symlink: ~/.zshenv -> <repo>/modules/zsh/home/.zshenv
export DOTFILES_DIR="${DOTFILES_DIR:-${${(%):-%x}:A:h:h:h:h}}"

# The environment every shell shares: Homebrew and the PATH order (shell module).
source "$HOME/.config/shell/env.sh"
# zsh's own share of Homebrew: completions, man and info pages.
if [[ -n $HOMEBREW_PREFIX ]]; then
  typeset -U fpath
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
  export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:" INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi
