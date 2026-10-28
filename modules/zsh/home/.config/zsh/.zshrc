# Entry point for interactive shells. Order matters: options, brew, plugins, modules, aliases, local.
source "$ZDOTDIR/options.zsh"

# Homebrew on PATH, both OSes. Static instead of `eval "$(brew shellenv)"`: same
# result, no process spawn, about 40 ms faster per shell.
for p in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
  [[ -x $p/bin/brew ]] || continue
  export HOMEBREW_PREFIX="$p" HOMEBREW_CELLAR="$p/Cellar" HOMEBREW_REPOSITORY="$p"
  [[ $p == /home/linuxbrew/.linuxbrew ]] && HOMEBREW_REPOSITORY="$p/Homebrew"
  path=("$p/bin" "$p/sbin" $path)
  fpath=("$p/share/zsh/site-functions" $fpath)
  export MANPATH="$p/share/man${MANPATH+:$MANPATH}:" INFOPATH="$p/share/info:${INFOPATH:-}"
  break
done
typeset -U path fpath

# Plugins via antidote, static mode: one generated file, rebuilt only when the list changes.
_antidote="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh"
if [[ -r $_antidote ]]; then
  source "$_antidote"
  if [[ ! $ZSH_CACHE/plugins.zsh -nt $ZDOTDIR/.zsh_plugins.txt ]]; then
    antidote bundle <"$ZDOTDIR/.zsh_plugins.txt" >|"$ZSH_CACHE/plugins.zsh"
  fi
  source "$ZSH_CACHE/plugins.zsh"
fi
unset _antidote

# Completion, after plugins so zsh-completions' fpath is in place. -C skips the
# security check; the dump is rebuilt when older than a day.
autoload -Uz compinit
if [[ -n $ZSH_CACHE/compdump(#qN.mh+24) || ! -f $ZSH_CACHE/compdump ]]; then
  compinit -d "$ZSH_CACHE/compdump"
else
  compinit -C -d "$ZSH_CACHE/compdump"
fi

# Per-module shell integration: modules/*/shell.zsh are linked here by install.
for f in "$ZDOTDIR"/rc.d/*.zsh(N); do source "$f"; done

source "$ZDOTDIR/aliases.zsh"
[[ -r $ZDOTDIR/local.zsh ]] && source "$ZDOTDIR/local.zsh"
