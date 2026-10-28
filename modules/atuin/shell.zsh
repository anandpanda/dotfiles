# atuin owns Ctrl-R. Up arrow stays plain zsh history on purpose.
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
