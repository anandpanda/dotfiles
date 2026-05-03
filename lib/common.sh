#!/bin/bash
# Shared helpers for install.sh and per-OS install scripts.
# Sourced — not run directly.

# ---------- OS / arch detection ----------

# detect_os — returns "linux", "macos", or "unknown"
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}

# Architecture for binary downloads (x86_64, aarch64)
ARCH="$(uname -m)"

# User-local bin dir for downloaded binaries (no sudo needed)
BIN_DIR="$HOME/.local/bin"

# ---------- Command checks ----------

# need <cmd> — true (0) if cmd is NOT on PATH.
# Use as: if need foo; then install_foo; fi
need() {
    ! command -v "$1" >/dev/null 2>&1
}

# have <cmd> — true (0) if cmd IS on PATH.
have() {
    command -v "$1" >/dev/null 2>&1
}

# apt_has <pkg> — true (0) if the package is available in apt.
# Doesn't trigger install. Quiet on stderr.
apt_has() {
    command -v apt-cache >/dev/null 2>&1 && apt-cache show "$1" >/dev/null 2>&1
}

# ---------- GitHub release binary installer ----------

# gh_install <repo> <asset-pattern> <bin-name>
# Installs (or upgrades) a binary from GitHub releases.
# - Compares installed version (from `<binname> --version`) with the latest
#   GitHub release tag.
# - Skips download if already at latest.
# - Otherwise downloads + extracts the release asset, placing <binname>
#   at $BIN_DIR/<binname>.
# - Handles .tar.gz, .tbz, .deb, bare binary.
#
# If the version comparison fails (offline, rate-limited, weird --version
# output), falls back to "always install" — better to re-download than miss
# an upgrade.
#
# Examples:
#   gh_install sharkdp/bat   "${ARCH}-unknown-linux-musl.tar.gz" bat
#   gh_install muesli/duf    "linux_${ARCH/x86_64/amd64}.deb"    duf
#   gh_install aristocratos/btop "${ARCH}-linux-musl.tbz"        btop
gh_install() {
    local repo="$1" pattern="$2" binname="$3"

    # Single API call — used for both version check and asset URL
    local api_json
    api_json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || true)"

    # Latest version (tag_name, with leading 'v' stripped)
    local latest=""
    if [ -n "$api_json" ]; then
        latest="$(echo "$api_json" | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')"
    fi

    # Currently installed version (best-effort parse)
    local current=""
    if have "$binname"; then
        current="$("$binname" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    fi

    # Skip if already at latest
    if [ -n "$current" ] && [ -n "$latest" ] && [ "$current" = "$latest" ]; then
        log_skip "$binname (latest: $current)"
        return 0
    fi

    # Find the asset URL matching the pattern.
    # Extract URLs FIRST, then grep against URL alone (so $-anchors work cleanly).
    local url=""
    if [ -n "$api_json" ]; then
        url="$(echo "$api_json" \
            | grep '"browser_download_url"' \
            | cut -d'"' -f4 \
            | grep -E "$pattern" \
            | head -1)"
    fi
    if [ -z "$url" ]; then
        log_warn "$binname: no release asset matched pattern '$pattern' for $repo"
        return 1
    fi

    # Download + extract + install
    mkdir -p "$BIN_DIR"
    local tmp src
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/asset"; then
        log_warn "$binname: download failed from $url"
        rm -rf "$tmp"
        return 1
    fi
    case "$url" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmp/asset" -C "$tmp"
            # Find the binary by name; some tarballs strip the executable bit.
            src="$(find "$tmp" -name "$binname" -type f ! -name '*.md' ! -name '*.txt' | head -1)"
            ;;
        *.tbz|*.tar.bz2)
            tar -xjf "$tmp/asset" -C "$tmp"
            src="$(find "$tmp" -name "$binname" -type f ! -name '*.md' ! -name '*.txt' | head -1)"
            ;;
        *.deb)
            sudo dpkg -i "$tmp/asset"
            rm -rf "$tmp"
            return 0
            ;;
        *)
            # Bare binary
            src="$tmp/asset"
            ;;
    esac
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        log_warn "$binname: binary not found in extracted asset"
        rm -rf "$tmp"
        return 1
    fi
    if ! install -m755 "$src" "$BIN_DIR/$binname"; then
        log_warn "$binname: install to $BIN_DIR failed"
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"

    if [ -n "$current" ]; then
        log_info "$binname upgraded $current → ${latest:-?} ($BIN_DIR/$binname)"
    else
        log_info "$binname installed at $BIN_DIR/$binname (version: ${latest:-?})"
    fi
}

# ---------- Logging helpers ----------

log_step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
log_info() { printf '    \033[36m✓\033[0m %s\n' "$*"; }
log_warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
log_skip() { printf '    \033[90m-\033[0m %s\n' "$*"; }
log_err()  { printf '    \033[31m✗\033[0m %s\n' "$*" >&2; }
