# PATH order: per-user programs (the official Claude installer, uv, pipx), then Homebrew, then the rest.
typeset -U path
[[ -z $HOMEBREW_PREFIX ]] || path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
path=("$HOME/.local/bin" $path)
