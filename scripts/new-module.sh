#!/usr/bin/env bash
# Scaffold modules/<name> with a README. Everything else is optional.
set -euo pipefail
name="${1:?usage: new-module.sh NAME}"
dir="$(cd "$(dirname "$0")/.." && pwd)/modules/$name"
[ -e "$dir" ] && {
  echo "exists: $dir" >&2
  exit 1
}
mkdir -p "$dir"
cat >"$dir/README.md" <<EOT
# $name

What it is, why it is here, and any keybindings worth remembering.

Optional files: Brewfile, config/ (-> ~/.config/$name), home/ (-> ~),
install.sh (idempotent post-link hook), module.toml (os = "macos"|"linux"),
CHECKLIST.md (manual steps printed after install).
EOT
echo "created $dir"
