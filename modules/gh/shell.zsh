# gh: the active GitHub account follows the directory, like git identity does.
# Accounts are remembered by install (preflight) in ~/.config/dotfiles/gh_{personal,work}.
# A wrapper checks before every gh call (gh's active account is global, so a chpwd hook
# would race between shells and miss shells that start inside a tree).
gh() {
  local ctx="" want cur f
  case "$PWD/" in
    "$HOME/work/"*) ctx=work ;;
    "$HOME/personal/"*) ctx=personal ;;
  esac
  if [[ -n $ctx ]]; then
    f="$HOME/.config/dotfiles/gh_$ctx"
    if [[ -r $f ]]; then
      want="$(<"$f")"
      cur="$(sed -n 's/^[[:space:]]*user:[[:space:]]*//p' "$HOME/.config/gh/hosts.yml" 2>/dev/null | head -1)"
      if [[ -n $want && $want != "$cur" ]]; then
        command gh auth switch --hostname github.com --user "$want" >/dev/null 2>&1 ||
          print -u2 "gh: could not switch to $want (logged out? run: gh auth login)"
      fi
    fi
  fi
  command gh "$@"
}
