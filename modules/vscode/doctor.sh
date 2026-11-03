#!/usr/bin/env bash
# Links present and correct; listed extensions installed; extras reported as info.
set -euo pipefail
for f in log os link module vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
here="$DOTFILES_DIR/modules/vscode"
udir="$(vscode_user_dir)"
rc=0
check() { # SRC DST
  if [ ! -L "$2" ]; then
    echo "missing link $2"
    rc=1
  elif [ "$(readlink "$2")" != "$1" ]; then
    echo "wrong link $2"
    rc=1
  fi
}
owned="$(mktemp)"
trap 'rm -f "$owned"' EXIT
vscode_owned_settings "$here/files/settings.json" >"$owned"
if [ -L "$udir/settings.json" ]; then
  echo "settings.json is a link into the repo (rerun install)"
  rc=1
elif [ ! -f "$udir/settings.json" ]; then
  echo "missing $udir/settings.json"
  rc=1
elif ! drifted="$(vscode_settings_drift "$owned" "$udir/settings.json")"; then
  while IFS= read -r k; do echo "setting drifted: $k"; done <<<"$drifted"
  rc=1
fi
for f in keybindings.json tasks.json; do check "$here/files/$f" "$udir/$f"; done
for f in "$here"/files/snippets/*.json; do check "$f" "$udir/snippets/$(basename "$f")"; done
check "$here/files/include/bits/stdc++.h" "$HOME/.local/include/bits/stdc++.h"

if vscode_bin >/dev/null; then
  wanted="$(vscode_wanted)"
  installed="$(vscode_installed)"
  while IFS= read -r id; do
    [ -n "$id" ] && echo "missing extension $id" && rc=1
  done < <(comm -23 <(printf '%s\n' "$wanted") <(printf '%s\n' "$installed"))
  while IFS= read -r id; do
    [ -n "$id" ] && echo "extra extension $id (dots vscode-prune)"
  done < <(comm -13 <(printf '%s\n' "$wanted") <(printf '%s\n' "$installed"))
fi
exit $rc
