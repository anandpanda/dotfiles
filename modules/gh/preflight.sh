#!/usr/bin/env bash
# Log in the GitHub accounts this profile needs and remember their usernames, so the
# shell can switch accounts by directory. Asks only when an account is not remembered.
set -euo pipefail
for f in log profile; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
command -v gh >/dev/null 2>&1 || {
  log_warn "gh not installed yet; GitHub login happens on the next install"
  exit 0
}
profile="${DOTFILES_PROFILE:-$(recall profile 2>/dev/null || echo personal)}"
ctxs="personal"
profile_has_overlay "$profile" 2>/dev/null && ctxs="personal work"
active_account() { gh auth status 2>&1 | awk '/Logged in to github.com account/ {acct=$6} /Active account: true/ {print acct; exit}'; }
for ctx in $ctxs; do
  if acct="$(recall "gh_$ctx" 2>/dev/null)" && [ -n "$acct" ]; then
    log_ok "gh $ctx account: $acct"
    continue
  fi
  if [ "${DRY_RUN:-0}" = 1 ] || ! is_tty; then
    echo "gh: log in your $ctx GitHub account, then rerun install:"
    echo "  gh auth login -h github.com -p ssh"
    continue
  fi
  ans=""
  ask "Log in your $ctx GitHub account now? [Y/n] " ans
  case "$ans" in n | N)
    log_warn "gh $ctx: skipped"
    continue
    ;;
  esac
  # gh's own prompts need the terminal; preflight runs with stdin on the tty already.
  gh auth login -h github.com -p ssh <"${DOTFILES_TTY:-/dev/tty}" || {
    log_warn "gh $ctx: login failed; rerun install to try again"
    continue
  }
  acct="$(active_account)"
  [ -n "$acct" ] || {
    log_warn "gh $ctx: could not read the account name"
    continue
  }
  remember "gh_$ctx" "$acct"
  log_ok "gh $ctx account: $acct"
done
