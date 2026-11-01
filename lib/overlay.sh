#!/usr/bin/env bash
# Private overlay: a second repo with modules/, applied after public modules.

overlay_default_url() { echo "git@github.com-personal:anandpanda/dotfiles-work.git"; }

overlay_resolve_url() {
  local url="$1"
  [ -n "$url" ] || url="$(recall overlay || overlay_default_url)"
  echo "$url"
}

# Fetching our own config depends on nothing the machine set up: global git config is
# ignored (a template's url rewrites) and ssh reads the repo's alias file, linked only later.
_overlay_git() {
  GIT_CONFIG_GLOBAL=/dev/null git -c core.sshCommand="ssh -F $(printf '%q' "$(ssh_github_conf)")" "$@"
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
    _overlay_git -C "$dir" pull --ff-only -q
  else
    log_info "overlay clone"
    _overlay_git clone -q "$url" "$dir"
  fi
}

overlay_apply() {
  local url dirs d brewfiles
  url="$(overlay_resolve_url "${1:-}")"
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
  _overlay_git -C "$dir" fetch -q 2>/dev/null || return 0 # offline: do not report stale
  behind="$(_overlay_git -C "$dir" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)"
  [ "$behind" = 0 ] || {
    echo "behind $behind"
    return 1
  }
}
