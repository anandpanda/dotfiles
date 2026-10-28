# atuin owns Ctrl-R. Up arrow stays plain zsh history on purpose.
# atuin's init spawns `atuin uuid` for a session id unless one is set; make one without a fork.
if [[ -z ${ATUIN_SESSION:-} || ${ATUIN_SHLVL:-} != $SHLVL ]]; then
  printf -v ATUIN_SESSION '%04x%04x%04x%04x%04x%04x%04x%04x' $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM
  export ATUIN_SESSION
  export ATUIN_SHLVL=$SHLVL
fi
zcache atuin atuin init zsh --disable-up-arrow
