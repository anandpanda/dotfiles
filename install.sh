#!/usr/bin/env bash
# Entry point. ./install.sh [PROFILE] [--dry-run] [--overlay URL]
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
for f in log os link profile module brew secrets ssh overlay; do
  # shellcheck disable=SC1090
  [ -f "$DOTFILES_DIR/lib/$f.sh" ] && source "$DOTFILES_DIR/lib/$f.sh"
done

DRY_RUN=0
OVERLAY_URL=""
PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --overlay)
      [ $# -ge 2 ] || die "--overlay needs a url"
      OVERLAY_URL="$2"
      shift
      ;;
    -h | --help)
      sed -n '2p' "$0"
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *) PROFILE="$1" ;;
  esac
  shift
done
export DRY_RUN
[ -n "$PROFILE" ] || PROFILE="$(recall profile || true)"
[ -n "$PROFILE" ] || PROFILE=personal
export DOTFILES_PROFILE="$PROFILE"
[ -n "$OVERLAY_URL" ] || OVERLAY_URL="$(recall overlay || true)"

os="$(os_name)" || die "unsupported OS: $(uname -s)"
log_info "profile: $PROFILE ($os/$(os_arch))"
[ "$DRY_RUN" = 1 ] && log_warn "dry run: nothing will change"

modules_root="${DOTFILES_MODULES:-$DOTFILES_DIR/modules}"
module_dirs=""
module_names="$(profile_modules "$PROFILE")" || die "cannot resolve profile: $PROFILE"
for m in $module_names; do
  d="$modules_root/$m"
  [ -d "$d" ] || die "module not found: $m"
  module_enabled_for_os "$d" || {
    log_info "skip $m (not for $os)"
    continue
  }
  module_dirs="$module_dirs $d"
done

if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ]; then
  brew_ensure
  # shellcheck disable=SC2086,SC2046
  brew_bundle $(module_brewfiles $module_dirs)
fi

for d in $module_dirs; do
  module_apply "$d" || die "module failed: $(basename "$d")"
done

if profile_has_overlay "$PROFILE" && type overlay_apply >/dev/null 2>&1; then
  overlay_apply "$OVERLAY_URL"
fi

if [ "$DRY_RUN" != 1 ]; then
  remember profile "$PROFILE"
fi

# shellcheck disable=SC2086
checklist="$(module_checklists $module_dirs)"
if [ -n "$checklist" ]; then
  log_info "manual steps:"
  echo "$checklist"
fi
log_ok "done"
