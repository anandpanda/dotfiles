#!/usr/bin/env bash
# Private overlay: a second repo with modules/, applied after public modules.

overlay_resolve_url() {
  local url="$1"
  [ -n "$url" ] || url="$(recall overlay || true)"
  if [ -z "$url" ] && is_tty; then
    printf 'Private overlay repo url (git@github.com:org/repo.git): '
    read -r url
  fi
  echo "$url"
}

overlay_ensure() {
  local url="$1" dir
  dir="$(overlay_dir)"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "clone or pull overlay $url -> $dir"
    return 0
  fi
  if [ -d "$dir/.git" ]; then
    log_info "overlay pull"
    git -C "$dir" pull --ff-only -q
  else
    log_info "overlay clone"
    git clone -q "$url" "$dir"
  fi
}

overlay_apply() {
  local url dir dirs="" d
  url="$(overlay_resolve_url "${1:-}")"
  if [ -z "$url" ]; then
    log_warn "no overlay url: skipping overlay"
    return 0
  fi
  overlay_ensure "$url" || die "overlay fetch failed"
  [ "${DRY_RUN:-0}" = 1 ] && return 0
  dir="$(overlay_dir)"
  for d in "$dir"/modules/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    module_enabled_for_os "$d" || continue
    dirs="$dirs $d"
  done
  if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ]; then
    # shellcheck disable=SC2086,SC2046
    brew_bundle $(module_brewfiles $dirs)
  fi
  for d in $dirs; do
    module_apply "$d" || die "overlay module failed: $(basename "$d")"
  done
  remember overlay "$url"
  log_ok "overlay applied"
}
