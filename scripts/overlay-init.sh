#!/usr/bin/env bash
# Create a private overlay repo skeleton at PATH from overlays/work.example.
set -euo pipefail
dest="${1:?usage: overlay-init.sh PATH}"
src="$(cd "$(dirname "$0")/.." && pwd)/overlays/work.example"
[ -e "$dest" ] && {
  echo "exists: $dest" >&2
  exit 1
}
mkdir -p "$dest"
cp -R "$src/." "$dest/"
git -C "$dest" init -q
git -C "$dest" add -A
git -C "$dest" -c user.name=overlay-init -c user.email=overlay-init@localhost commit -qm "chore: overlay skeleton"
echo "created $dest"
echo "next: edit modules/git/config/identity.work, push to a private repo,"
echo "      then: just install work --overlay <repo-url>"
