#!/usr/bin/env bash
# Read-only drift report. Exit 1 if anything needs fixing.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
for f in log os link profile module brew secrets overlay; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done

problems=0
problem() {
  log_fail "$*"
  problems=$((problems + 1))
}

profile="$(recall profile || echo personal)"
log_info "profile: $profile"

modules_root="${DOTFILES_MODULES:-$DOTFILES_DIR/modules}"
dirs=""
module_names="$(profile_modules "$profile")" || die "cannot resolve profile: $profile"
for m in $module_names; do
  d="$modules_root/$m"
  [ -d "$d" ] || {
    problem "module missing: $m"
    continue
  }
  module_enabled_for_os "$d" && dirs="$dirs $d"
done
if profile_has_overlay "$profile"; then
  if [ -d "$(overlay_dir)/.git" ]; then
    log_ok "overlay present ($(recall overlay || echo 'url unknown'))"
    for d in "$(overlay_dir)"/modules/*/; do
      d="${d%/}"
      [ -d "$d" ] && module_enabled_for_os "$d" && dirs="$dirs $d"
    done
  else
    problem "overlay missing: run install.sh $profile"
  fi
fi

# Links
check_link() { # SRC DST
  if [ ! -L "$2" ]; then
    problem "missing link $2"
  elif [ "$(readlink "$2")" != "$1" ]; then
    problem "wrong link $2 -> $(readlink "$2")"
  fi
}
link_problems_before=$problems
managed=""
for d in $dirs; do
  name="$(basename "$d")"
  if [ -d "$d/config" ]; then
    managed="$managed $name"
    if owner="$(module_config_owner "$name" "$d/config")"; then
      while IFS= read -r f; do check_link "$f" "$owner/${f#"$d"/config/}"; done < <(find "$d/config" -type f)
    else
      check_link "$d/config" "$HOME/.config/$name"
    fi
  fi
  if [ -d "$d/home" ]; then
    while IFS= read -r f; do check_link "$f" "$HOME/${f#"$d"/home/}"; done < <(find "$d/home" -type f)
  fi
done
[ "$problems" = "$link_problems_before" ] && log_ok "links"

# Unmanaged ~/.config entries (informational)
if [ -d "$HOME/.config" ]; then
  for e in "$HOME/.config"/*; do
    [ -e "$e" ] || continue
    n="$(basename "$e")"
    [ "$n" = dotfiles ] && continue
    case " $managed " in *" $n "*) ;; *) printf 'unmanaged %s\n' "$e" ;; esac
  done
fi

# Brew
if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ] && command -v brew >/dev/null; then
  # shellcheck disable=SC2086,SC2046
  missing="$(brew_missing $(module_brewfiles $dirs))"
  if [ -n "$missing" ]; then problem "brew missing: $(echo "$missing" | tr '\n' ' ')"; else log_ok "brew"; fi
fi

# Secrets
missing="$(secrets_missing)"
if [ -n "$missing" ]; then
  log_warn "secrets missing:"
  while IFS= read -r line; do echo "  $line"; done <<<"$missing"
else
  log_ok "secrets"
fi

if [ "$problems" = 0 ]; then
  log_ok "doctor: clean"
  exit 0
fi
log_fail "doctor: $problems problem(s)"
exit 1
