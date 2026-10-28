# gh: the active GitHub account follows the directory, like git identity does.
# Accounts are remembered by install (preflight) in ~/.config/dotfiles/gh_{personal,work}.
_dotfiles_gh_ctx=""
_dotfiles_gh_switch() {
  (( $+commands[gh] )) || return 0
  local ctx=""
  case "$PWD/" in
    "$HOME/work/"*) ctx=work ;;
    "$HOME/personal/"*) ctx=personal ;;
    *) return 0 ;;
  esac
  [[ $ctx == "$_dotfiles_gh_ctx" ]] && return 0
  local f="$HOME/.config/dotfiles/gh_$ctx" acct
  [[ -r $f ]] || return 0
  acct="$(<"$f")"
  [[ -n $acct ]] || return 0
  gh auth switch --hostname github.com --user "$acct" >/dev/null 2>&1 && _dotfiles_gh_ctx="$ctx"
  return 0
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _dotfiles_gh_switch
