# Entry point for interactive shells. Order matters: options, brew, plugins, modules, aliases, local.
source "$ZDOTDIR/options.zsh"

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

# Completion, after plugins so zsh-completions' fpath is in place. A full compinit
# once a day (it only rewrites the dump when the function list changed, so we
# touch it to mark the check done); -C skips the security scan the rest of the time.
# -i: silently ignore insecure dirs instead of prompting (which would hang or abort
# with no terminal, and skip writing the dump).
autoload -Uz compinit
_dotfiles_compinit() {
  setopt localoptions extendedglob
  local dump="$ZSH_CACHE/compdump"
  if [[ -n $dump(#qN.mh+24) || ! -f $dump ]]; then
    compinit -i -d "$dump" && touch "$dump"
  else
    compinit -C -d "$dump"
  fi
}
_dotfiles_compinit

# Per-module shell integration: modules/*/shell.zsh are linked here by install.
for f in "$ZDOTDIR"/rc.d/*.zsh(N); do source "$f"; done

source "$ZDOTDIR/aliases.zsh"
[[ -r $ZDOTDIR/local.zsh ]] && source "$ZDOTDIR/local.zsh"
