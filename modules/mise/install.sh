#!/usr/bin/env bash
# Install the global tools from config.toml that are not present yet.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
command -v mise >/dev/null 2>&1 || {
  log_warn "mise not installed yet; runtimes install on the next run"
  exit 0
}
missing="$(mise ls --missing 2>/dev/null | grep -v '^$' || true)"
if [ -z "$missing" ]; then
  echo "skip mise tools"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] mise install ($(echo "$missing" | wc -l | tr -d ' ') tool(s))"
  exit 0
fi
mise install
echo "installed mise tools"
