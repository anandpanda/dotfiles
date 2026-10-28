#!/usr/bin/env bash
# Set gh aliases idempotently. gh's config.yml is not linked: gh writes hosts and tokens there.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
command -v gh >/dev/null 2>&1 || {
  log_warn "gh not installed yet; aliases set on the next install"
  exit 0
}
wanted="pc=pr create --fill --web
pv=pr view --web
co=pr checkout
pm=pr merge --squash --delete-branch
prs=pr list --author @me
runs=run list --limit 5"
current="$(gh alias list 2>/dev/null || true)"
changed=0
while IFS='=' read -r name cmd; do
  [ -n "$name" ] || continue
  if printf '%s\n' "$current" | grep -qxF "$name: $cmd"; then continue; fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] gh alias set $name '$cmd'"
  else
    if gh alias set --clobber "$name" "$cmd" >/dev/null 2>&1; then echo "alias $name = $cmd"; else log_warn "could not set gh alias $name"; fi
  fi
  changed=1
done <<<"$wanted"
[ "$changed" = 1 ] || echo "skip gh aliases"
