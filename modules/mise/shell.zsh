# mise: runtimes and per-project env. Evaluated live, not cached: its output embeds the
# PATH at generation time, so a cached copy would clobber entries added since (~10 ms).
(( $+commands[mise] )) && eval "$(mise activate zsh)"
