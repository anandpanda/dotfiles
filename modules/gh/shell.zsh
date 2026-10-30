# gh: the active GitHub account follows the directory, like git identity does.
# Accounts are remembered by install (preflight) in ~/.config/dotfiles/gh_{personal,work};
# the context comes from the folder lists install collects in ~/.config/dotfiles/contexts.
# A wrapper checks before every gh call (gh's active account is global, so a chpwd hook
# would race between shells and miss shells that start inside a tree).
gh() {
  local ctx="" want cur f c d best=0
  if [[ -r $HOME/.config/dotfiles/contexts ]]; then
    while IFS=$'\t' read -r c d; do
      [[ -n $d && "$PWD/" == "$d/"* && ${#d} -gt $best ]] || continue
      ctx=$c best=${#d}
    done <"$HOME/.config/dotfiles/contexts"
  fi
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
