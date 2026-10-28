#!/usr/bin/env bash
# Uninstall VS Code extensions that are on no list (ours or the overlay's), after confirmation.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_DIR
for f in log os link module vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
command -v code >/dev/null 2>&1 || die "code is not on PATH"
extras="$(comm -13 <(vscode_wanted) <(vscode_installed))"
if [ -z "$extras" ]; then
  echo "nothing to prune"
  exit 0
fi
echo "extensions not on any list:"
printf '%s\n' "$extras" | sed 's/^/  /'
n="$(printf '%s\n' "$extras" | grep -c .)"
ans=""
ask "Uninstall these $n extensions? [y/N] " ans
case "$ans" in y | Y) ;; *)
  echo "kept"
  exit 0
  ;;
esac
while IFS= read -r id; do
  [ -n "$id" ] || continue
  if code --uninstall-extension "$id" >/dev/null 2>&1; then echo "removed $id"; else log_warn "could not remove $id"; fi
done <<<"$extras"
