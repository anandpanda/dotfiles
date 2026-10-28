#!/usr/bin/env bash
# System defaults. Each line says what it does. Only writes when a value differs.
set -euo pipefail
[ "$(uname -s)" = Darwin ] || exit 0
# `defaults` ignores $HOME, so a test or sandbox run with a fake HOME would
# change the real user's settings. Refuse unless explicitly allowed.
real_home="$(eval echo "~$(id -un)")"
if [ "$HOME" != "$real_home" ] && [ "${DOTFILES_ALLOW_FAKE_HOME:-0}" != 1 ]; then
  echo "skip macos defaults: HOME is not the real home ($real_home)"
  exit 0
fi

changed=0
set_default() { # DOMAIN KEY TYPE VALUE
  local cur
  cur="$(defaults read "$1" "$2" 2>/dev/null || echo "__unset__")"
  case "$3" in
    -bool)
      [ "$cur" = 1 ] && cur=true
      [ "$cur" = 0 ] && cur=false
      ;;
  esac
  [ "$cur" = "$4" ] && return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] defaults write $1 $2 $3 $4"
    return 0
  fi
  defaults write "$1" "$2" "$3" "$4"
  echo "set $1 $2 = $4"
  changed=1
}

# Keyboard: fast repeat, short delay, hold-to-repeat instead of accent popup,
# no autocorrect, auto-capitalise, smart quotes, smart dashes, or double-space period.
set_default NSGlobalDomain KeyRepeat -int 2
set_default NSGlobalDomain InitialKeyRepeat -int 15
set_default NSGlobalDomain ApplePressAndHoldEnabled -bool false
set_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
set_default NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
set_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
set_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
set_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Trackpad: tap to click (built-in and bluetooth).
set_default com.apple.AppleMultitouchTrackpad Clicking -bool true
set_default com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Finder: show extensions, path bar, status bar, list view, folders first,
# no warning when changing an extension.
set_default NSGlobalDomain AppleShowAllExtensions -bool true
set_default com.apple.finder ShowPathbar -bool true
set_default com.apple.finder ShowStatusBar -bool true
set_default com.apple.finder FXPreferredViewStyle -string Nlsv
set_default com.apple.finder FXEnableExtensionChangeWarning -bool false
set_default com.apple.finder _FXSortFoldersFirst -bool true

# Dock: autohide with no delay, no recent apps, smaller icons, fast Mission Control.
set_default com.apple.dock autohide -bool true
set_default com.apple.dock show-recents -bool false
set_default com.apple.dock tilesize -int 40
set_default com.apple.dock autohide-delay -float 0
set_default com.apple.dock expose-animation-duration -float 0.1

# Screenshots: png into ~/Screenshots, no window shadow.
mkdir -p "$HOME/Screenshots"
set_default com.apple.screencapture location -string "$HOME/Screenshots"
set_default com.apple.screencapture type -string png
set_default com.apple.screencapture disable-shadow -bool true

if [ "$changed" = 1 ]; then
  killall Finder Dock SystemUIServer 2>/dev/null || true
  echo "restarted Finder and Dock"
fi
