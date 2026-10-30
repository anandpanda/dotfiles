#!/usr/bin/env bash
# Private overlay: a second repo with modules/, applied after public modules.

overlay_resolve_url() {
  local url="$1"
  [ -n "$url" ] || url="$(recall overlay || true)"
  if [ -z "$url" ] && is_tty; then
    ask 'Private overlay repo url (git@github.com-personal:you/dotfiles-work.git): ' url
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
    # The url is used as given: its ssh host alias (github.com-personal or -work) picks the key.
    git clone -q "$url" "$dir"
  fi
}

overlay_apply() {
  local url dirs d brewfiles
  url="$(overlay_resolve_url "${1:-}")"
  if [ -z "$url" ]; then
    log_warn "no overlay url: skipping overlay"
    return 0
  fi
  if [ "${OVERLAY_FETCHED:-0}" != 1 ]; then
    overlay_ensure "$url" || die "overlay fetch failed"
  fi
  dirs="$(overlay_module_dirs)"
  if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ]; then
    brewfiles="$(printf '%s\n' "$dirs" | module_brewfiles_stdin)"
    [ -z "$brewfiles" ] || brew_bundle_stdin <<<"$brewfiles"
  fi
  preflight_run "$dirs" || die "overlay preflight failed"
  while IFS= read -r d <&3; do
    [ -n "$d" ] || continue
    module_apply "$d" || die "overlay module failed: $(basename "$d")"
  done 3<<<"$dirs"
  [ "${DRY_RUN:-0}" = 1 ] || remember overlay "$url"
  log_ok "overlay applied"
}

# 0 if the overlay checkout is at its remote's head; prints "behind N" otherwise.
overlay_is_fresh() {
  local dir behind
  dir="$(overlay_dir)"
  [ -d "$dir/.git" ] || return 1
  git -C "$dir" fetch -q 2>/dev/null || return 0 # offline: do not report stale
  behind="$(git -C "$dir" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)"
  [ "$behind" = 0 ] || {
    echo "behind $behind"
    return 1
  }
}
