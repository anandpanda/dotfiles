# git: worktree helpers and lazygit
# gwt <branch> [base]: new worktree as a sibling dir "<repo>-<branch>", branch created from base (default: current HEAD), then cd into it.
gwt() {
  local branch="$1" base="${2:-HEAD}" root name dest
  [[ -n $branch ]] || { echo "usage: gwt <branch> [base]" >&2; return 1; }
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo" >&2; return 1; }
  name="${root:t}"
  dest="${root:h}/${name}-${branch//\//-}"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$dest" "$branch" || return 1
  else
    git worktree add -b "$branch" "$dest" "$base" || return 1
  fi
  cd "$dest"
}
# gwtl: list worktrees. gwtr <path-or-branch>: remove one.
gwtl() { git worktree list; }
gwtr() {
  local t="$1"
  [[ -n $t ]] || { echo "usage: gwtr <path-or-branch>" >&2; return 1; }
  [[ -d $t ]] || t="$(git worktree list --porcelain | awk -v b="refs/heads/$t" '$1=="worktree"{p=$2} $1=="branch"&&$2==b{print p}')"
  [[ -n $t ]] || { echo "no worktree for $1" >&2; return 1; }
  git worktree remove "$t"
}
(( $+commands[lazygit] )) && alias lg='lazygit'
