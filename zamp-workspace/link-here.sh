#!/bin/bash
# Link this workspace's .claude/ and .mcp.json into a target directory via
# symlinks. Edits at <target>/.claude/<file> flow back to the dotfiles repo
# automatically; commit + push from ~/dotfiles to share across machines.
#
# Usage:
#   bash link-here.sh                  # link into $PWD
#   bash link-here.sh /path/to/dir     # link into specific directory
#
# Idempotent: if already symlinked correctly, skips. Pre-existing real
# files/dirs get backed up to *.backup.<timestamp> before linking.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$PWD}"

if [ ! -d "$TARGET" ]; then
    echo "Error: target directory '$TARGET' does not exist." >&2
    exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

echo "==> Linking zamp-workspace contents into: $TARGET"
echo "    source: $SCRIPT_DIR"

link_one() {
    local item="$1"
    local src="$SCRIPT_DIR/$item"
    local target="$TARGET/$item"

    if [ ! -e "$src" ]; then
        echo "    - source missing: $src — skipping"
        return
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        echo "    - $item already symlinked"
        return
    fi

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        echo "    ! moved existing $target → $backup"
    fi

    ln -sfn "$src" "$target"
    echo "    ✓ $item → $target"
}

link_one .claude
link_one .mcp.json

echo "Done."
