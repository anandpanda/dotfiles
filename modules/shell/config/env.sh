# The environment every shell shares (zsh, bash, sh): Homebrew's variables and the PATH
# order ~/.local/bin, mise shims, Homebrew, then the rest. Plain sh; sourcing twice is harmless.
for _dots_p in "$HOME/.brew" /opt/homebrew /usr/local; do
  if [ -x "$_dots_p/bin/brew" ]; then
    HOMEBREW_PREFIX=$_dots_p
    HOMEBREW_CELLAR=$_dots_p/Cellar
    HOMEBREW_REPOSITORY=$_dots_p
    [ ! -d "$_dots_p/Homebrew" ] || HOMEBREW_REPOSITORY=$_dots_p/Homebrew
    export HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY
    break
  fi
done

_dots_front() {
  _dots_new=$1
  _dots_ifs=$IFS
  IFS=:
  for _dots_d in $PATH; do
    [ "$_dots_d" = "$1" ] || _dots_new=$_dots_new:$_dots_d
  done
  IFS=$_dots_ifs
  PATH=$_dots_new
}
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  _dots_front "$HOMEBREW_PREFIX/sbin"
  _dots_front "$HOMEBREW_PREFIX/bin"
fi
_dots_front "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
_dots_front "$HOME/.local/bin"
export PATH
unset -f _dots_front
unset _dots_p _dots_new _dots_ifs _dots_d
