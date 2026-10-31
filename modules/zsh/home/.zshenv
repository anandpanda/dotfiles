# Read by every zsh, login or not. Points zsh at XDG config; everything else lives there.
export ZDOTDIR="$HOME/.config/zsh"
# The repo root, found through this file's own symlink: ~/.zshenv -> <repo>/modules/zsh/home/.zshenv
export DOTFILES_DIR="${DOTFILES_DIR:-${${(%):-%x}:A:h:h:h:h}}"

# Homebrew on PATH for every zsh, login or script. Static instead of `brew shellenv`:
# same result, no process spawn.
for _p in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  [[ -x $_p/bin/brew ]] || continue
  export HOMEBREW_PREFIX="$_p" HOMEBREW_CELLAR="$_p/Cellar" HOMEBREW_REPOSITORY="$_p"
  [[ $_p == /home/linuxbrew/.linuxbrew ]] && HOMEBREW_REPOSITORY="$_p/Homebrew"
  typeset -U path fpath
  path=("$_p/bin" "$_p/sbin" $path)
  fpath=("$_p/share/zsh/site-functions" $fpath)
  export MANPATH="$_p/share/man${MANPATH+:$MANPATH}:" INFOPATH="$_p/share/info:${INFOPATH:-}"
  break
done
unset _p

# Per-user programs (the official Claude installer, uv, pipx) win over Homebrew copies.
typeset -U path
path=("$HOME/.local/bin" $path)
