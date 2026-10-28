#!/usr/bin/env bash
# Make Homebrew zsh the login shell. Needs a password, so it runs in preflight.
set -euo pipefail
source "$DOTFILES_DIR/lib/log.sh"
source "$DOTFILES_DIR/lib/profile.sh"
want=""
for p in /opt/homebrew/bin/zsh /usr/local/bin/zsh /home/linuxbrew/.linuxbrew/bin/zsh; do
  [ -x "$p" ] && want="$p" && break
done
[ -n "$want" ] || {
  log_warn "login shell: homebrew zsh not installed yet (rerun install after packages)"
  exit 0
}
if [ "$(uname -s)" = Darwin ]; then
  cur="$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}')"
else
  cur="$(getent passwd "$(id -un)" | cut -d: -f7)"
fi
if [ "$cur" = "$want" ]; then
  log_ok "login shell ok ($want)"
  exit 0
fi
if [ "$(recall login_shell 2>/dev/null || true)" = skip ]; then
  log_info "login shell: kept $cur (you declined earlier; remove ~/.config/dotfiles/login_shell to be asked again)"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ] || ! is_tty; then
  echo "login shell is $cur. To switch to $want run:"
  echo "  grep -qxF '$want' /etc/shells || echo '$want' | sudo tee -a /etc/shells"
  echo "  chsh -s '$want'"
  exit 0
fi
ans=""
ask "Switch login shell from $cur to $want? [Y/n] " ans
case "$ans" in n | N)
  remember login_shell skip
  log_warn "kept $cur"
  exit 0
  ;;
esac
if ! grep -qxF "$want" /etc/shells; then
  echo "$want" | sudo tee -a /etc/shells >/dev/null || {
    log_warn "login shell: could not add $want to /etc/shells; rerun install to try again"
    exit 0
  }
fi
if chsh -s "$want"; then
  log_ok "login shell is now $want (takes effect in new terminals)"
else
  log_warn "login shell: chsh failed; rerun install to try again"
fi
