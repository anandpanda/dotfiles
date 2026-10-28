# starship prompt
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
# starship's init runs `starship prompt --continuation` at source time (a spawn per shell);
# the continuation prompt is a constant, so bake it in once.
ZCACHE_FILTER='s/^PROMPT2=.*/PROMPT2="∙ "/' zcache starship starship init zsh
