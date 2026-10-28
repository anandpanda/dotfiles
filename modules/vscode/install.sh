#!/usr/bin/env bash
# Link config into VS Code's per-OS user dir and install any missing extensions.
set -euo pipefail
for f in log os link module vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
here="$DOTFILES_DIR/modules/vscode"
udir="$(vscode_user_dir)"

# Linux: VS Code is not a brew cask there; use Microsoft's apt repo when apt exists.
if [ "$(os_name)" = linux ] && ! command -v code >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] add Microsoft apt repo and install code"
  else
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
      sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq code >/dev/null
  fi
fi

# Config: linked file by file so VS Code's own state in the user dir is untouched.
if [ "${DRY_RUN:-0}" = 1 ]; then
  [ -d "$udir/snippets" ] || echo "[dry] mkdir $udir/snippets"
else
  mkdir -p "$udir/snippets"
fi
for f in settings.json keybindings.json tasks.json; do link_file "$here/files/$f" "$udir/$f"; done
for f in "$here"/files/snippets/*.json; do link_file "$f" "$udir/snippets/$(basename "$f")"; done

# Extensions: ours plus the overlay's, minus what is already installed.
if ! command -v code >/dev/null 2>&1; then
  log_warn "code is not on PATH: extensions not installed (open VS Code once, then rerun)"
  exit 0
fi
wanted="$(vscode_wanted)"
installed="$(vscode_installed)"
missing="$(comm -23 <(printf '%s\n' "$wanted") <(printf '%s\n' "$installed"))"
if [ -z "$missing" ]; then
  echo "skip extensions"
  exit 0
fi
while IFS= read -r id; do
  [ -n "$id" ] || continue
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] install extension $id"
  else
    if code --install-extension "$id" --force >/dev/null 2>&1; then echo "installed $id"; else log_warn "could not install $id"; fi
  fi
done <<<"$missing"
