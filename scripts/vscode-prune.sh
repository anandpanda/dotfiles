#!/usr/bin/env bash
# Uninstall VS Code extensions that are on no list (ours or the overlay's), after confirmation.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_DIR
for f in log os link module vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
code_bin="$(vscode_bin)" || die "code CLI not found"
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
uninstall_all() { # LIST
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if "$code_bin" --uninstall-extension "$id" >/dev/null 2>&1; then echo "removed $id"; else log_warn "could not remove $id"; fi
  done <<<"$1"
}
uninstall_all "$extras"
# Uninstalling a pack takes its members with it, listed ones included: put those back.
missing="$(comm -23 <(vscode_wanted) <(vscode_installed))"
while IFS= read -r id; do
  [ -n "$id" ] || continue
  if "$code_bin" --install-extension "$id" --force >/dev/null 2>&1; then echo "restored $id"; else log_warn "could not restore $id"; fi
done <<<"$missing"
# Pack members VS Code refused to remove in the first pass usually go on the second.
extras="$(comm -13 <(vscode_wanted) <(vscode_installed))"
[ -z "$extras" ] || uninstall_all "$extras"
extras="$(comm -13 <(vscode_wanted) <(vscode_installed))"
if [ -z "$extras" ]; then
  echo "clean: installed extensions match the list"
else
  log_warn "still extra: $(echo "$extras" | tr '\n' ' ')"
fi
