#!/usr/bin/env bash
# Make Homebrew zsh the login shell. Needs a password, so it runs in preflight.
set -euo pipefail
source "$DOTFILES_DIR/lib/log.sh"
want=""
for p in /opt/homebrew/bin/zsh /usr/local/bin/zsh /home/linuxbrew/.linuxbrew/bin/zsh; do
  [ -x "$p" ] && want="$p" && break
done
[ -n "$want" ] || {
  log_warn "homebrew zsh not installed; it will be after brew bundle"
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
if [ "${DRY_RUN:-0}" = 1 ] || ! is_tty; then
  echo "login shell is $cur. To switch to $want run:"
  echo "  grep -qxF '$want' /etc/shells || echo '$want' | sudo tee -a /etc/shells"
  echo "  chsh -s '$want'"
  exit 0
fi
printf 'Switch login shell from %s to %s? [Y/n] ' "$cur" "$want"
read -r ans
case "$ans" in n | N)
  log_warn "kept $cur"
  exit 0
  ;;
esac
grep -qxF "$want" /etc/shells || echo "$want" | sudo tee -a /etc/shells >/dev/null
chsh -s "$want" && log_ok "login shell is now $want (takes effect in new terminals)"
