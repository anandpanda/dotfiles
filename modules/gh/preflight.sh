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
# "✓ Logged in to github.com account NAME (keyring)" then "- Active account: true"; the
# glyph shifts columns, so take the word after "account".
active_account() {
  gh auth status 2>&1 | awk '/Logged in to .* account / { for (i = 1; i < NF; i++) if ($i == "account") acct = $(i + 1) } /Active account: true/ { print acct; exit }'
}
logged_in() { gh auth status 2>/dev/null | awk '/Logged in to .* account / { for (i = 1; i < NF; i++) if ($i == "account") print $(i + 1) }'; }
for ctx in $ctxs; do
  if acct="$(recall "gh_$ctx" 2>/dev/null)" && [ -n "$acct" ]; then
    log_ok "gh $ctx account: $acct"
    continue
  fi
  # Already logged in and not claimed by the other context: just record it.
  other="personal"
  [ "$ctx" = personal ] && other="work"
  taken="$(recall "gh_$other" 2>/dev/null || true)"
  for a in $(logged_in); do
    if [ "$a" != "$taken" ]; then
      remember "gh_$ctx" "$a"
      log_ok "gh $ctx account: $a (already logged in)"
      continue 2
    fi
  done
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
  if [ "$acct" = "$taken" ]; then
    log_warn "gh $ctx: that is the same account as $other ($acct); log out of GitHub in the browser and rerun install"
    continue
  fi
  remember "gh_$ctx" "$acct"
  log_ok "gh $ctx account: $acct"
done
