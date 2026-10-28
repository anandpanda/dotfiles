#!/usr/bin/env bash
# OS and architecture detection.

os_name() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    *) return 1 ;;
  esac
}

os_arch() {
  case "$(uname -m)" in
    arm64 | aarch64) echo arm64 ;;
    x86_64 | amd64) echo x86_64 ;;
    *) return 1 ;;
  esac
}

brew_prefix() {
  case "$(os_name)/$(os_arch)" in
    macos/arm64) echo /opt/homebrew ;;
    macos/x86_64) echo /usr/local ;;
    linux/*) echo /home/linuxbrew/.linuxbrew ;;
  esac
}
