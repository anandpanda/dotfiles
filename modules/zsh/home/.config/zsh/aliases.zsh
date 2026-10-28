# Safety first
alias rm='rm -i' cp='cp -i' mv='mv -i'

# Modern replacements, only when the tool is present. Escape with a backslash (\ls) for the original.
(( $+commands[eza] )) && {
  alias ls='eza --group-directories-first'
  alias ll='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
}
(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[btop] )) && alias top='btop'
(( $+commands[rg] )) && alias grep='rg'
(( $+commands[fd] )) && alias find='fd'

alias ..='cd ..'
alias ...='cd ../..'
alias reload='exec zsh'
alias dot='cd "$DOTFILES_DIR"'
