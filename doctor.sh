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
module_names="$(profile_modules "$profile")" || die "cannot resolve profile: $profile"
dirs=""
while IFS= read -r m; do
  [ -n "$m" ] || continue
  d="$modules_root/$m"
  [ -d "$d" ] || {
    problem "module missing: $m"
    continue
  }
  module_enabled_for_os "$d" && dirs="$dirs$d
"
done <<<"$module_names"
if profile_has_overlay "$profile"; then
  if [ -d "$(overlay_dir)/.git" ]; then
    if fresh="$(overlay_is_fresh)"; then
      log_ok "overlay present ($(recall overlay || echo 'url unknown'))"
    else
      problem "overlay $fresh: run install.sh $profile"
    fi
    for d in "$(overlay_dir)"/modules/*/; do
      d="${d%/}"
      [ -d "$d" ] && module_enabled_for_os "$d" && dirs="$dirs$d
"
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
managed_names=" "
while IFS= read -r d; do
  [ -n "$d" ] || continue
  name="$(basename "$d")"
  managed_names="$managed_names $name "
  if [ -d "$d/config" ]; then
    managed="$managed $name"
    if owner="$(module_config_owner "$name" "$d")"; then
      while IFS= read -r f; do
        dst="$owner/${f#"$d"/config/}"
        [ -e "$dst" ] && [ ! -L "$dst" ] && continue # public file wins, overlay skipped it
        check_link "$f" "$dst"
      done < <(find "$d/config" -type f)
    else
      check_link "$d/config" "$HOME/.config/$name"
    fi
  fi
  if [ -f "$d/shell.zsh" ]; then
    rc="$HOME/.config/zsh/rc.d/$name.zsh"
    case "$d" in "$(overlay_dir)"/*) rc="$HOME/.config/zsh/rc.d/$name.overlay.zsh" ;; esac
    check_link "$d/shell.zsh" "$rc"
  fi
  if [ -d "$d/home/.config" ]; then
    for sub in "$d/home/.config"/*/; do
      [ -d "$sub" ] && managed="$managed $(basename "$sub")"
    done
  fi
  [ -f "$d/shell.zsh" ] && managed="$managed zsh"
  if [ -d "$d/home" ]; then
    while IFS= read -r f; do
      dst="$HOME/${f#"$d"/home/}"
      cur="$(readlink "$dst" 2>/dev/null || true)"
      case "$cur" in "$(overlay_dir)"/*) [ "$d" = "${d#"$(overlay_dir)"}" ] && continue ;; esac # overlay owns it
      check_link "$f" "$dst"
    done < <(find "$d/home" -type f)
  fi
done <<<"$dirs"
[ "$problems" = "$link_problems_before" ] && log_ok "links"

# ssh include line (only when the ssh module is enabled)
case "$managed_names" in *" ssh "*)
  if [ -f "$HOME/.ssh/config" ] && grep -qxF 'Include ~/.ssh/conf.d/*.conf' "$HOME/.ssh/config"; then
    log_ok "ssh include"
  else
    problem "ssh include missing in ~/.ssh/config"
  fi
  ;;
esac

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
  brewfiles="$(printf '%s' "$dirs" | module_brewfiles_stdin)"
  missing=""
  [ -z "$brewfiles" ] || missing="$(brew_missing_stdin <<<"$brewfiles")"
  if [ -n "$missing" ]; then problem "brew missing: $(echo "$missing" | tr '\n' ' ')"; else log_ok "brew"; fi
fi

# Login shell (only when the zsh module is enabled)
case "$managed_names" in *" zsh "*)
  want=""
  for p in /opt/homebrew/bin/zsh /usr/local/bin/zsh /home/linuxbrew/.linuxbrew/bin/zsh; do
    [ -x "$p" ] && want="$p" && break
  done
  if [ "$(uname -s)" = Darwin ]; then
    cur="$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}')"
  else
    cur="$(getent passwd "$(id -un)" | cut -d: -f7)"
  fi
  if [ -z "$want" ]; then
    problem "login shell: homebrew zsh not installed"
  elif [ "$cur" != "$want" ]; then
    problem "login shell is $cur, want $want (rerun install)"
  else log_ok "login shell $want"; fi
  ;;
esac

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
