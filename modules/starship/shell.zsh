# starship prompt
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
(( $+commands[starship] )) && eval "$(starship init zsh)"
