#!/usr/bin/env bash
# Blank machine to installed dotfiles. Safe to pipe to bash.
#   curl -fsSL https://raw.githubusercontent.com/anandpanda/dotfiles/main/bootstrap.sh | bash -s -- [profile] [overlay-url]
set -euo pipefail
profile="${1:-personal}"
overlay="${2:-}"
repo="https://github.com/anandpanda/dotfiles.git"
dest="$HOME/.dotfiles"

case "$(uname -s)" in
  Darwin)
    xcode-select -p >/dev/null 2>&1 || {
      xcode-select --install
      echo "re-run after Xcode Command Line Tools finish installing"
      exit 1
    }
    prefix=/opt/homebrew
    [ "$(uname -m)" = x86_64 ] && prefix=/usr/local
    # Homebrew's non-interactive installer needs cached sudo on macOS.
    sudo -v
    ;;
  Linux)
    sudo apt-get update -qq && sudo apt-get install -y -qq build-essential curl file git procps >/dev/null
    prefix=/home/linuxbrew/.linuxbrew
    ;;
  *)
    echo "unsupported OS" >&2
    exit 1
    ;;
esac

if [ ! -x "$prefix/bin/brew" ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$prefix/bin/brew" shellenv)"
brew install -q git just

if [ -d "$dest/.git" ]; then git -C "$dest" pull --ff-only -q; else git clone -q "$repo" "$dest"; fi
cd "$dest"
# When piped from curl, stdin is the pipe; reattach the terminal so the
# guided ssh key and overlay prompts can run.
in=/dev/stdin
[ -t 0 ] || { [ -r /dev/tty ] && in=/dev/tty; }
if [ -n "$overlay" ]; then
  ./install.sh "$profile" --overlay "$overlay" <"$in"
else
  ./install.sh "$profile" <"$in"
fi
