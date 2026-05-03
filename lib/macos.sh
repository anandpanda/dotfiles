#!/bin/bash
# macOS tool installs via Homebrew — upgrade-aware.
# Strategy:
#   - If already installed: brew upgrade (no-op if at latest)
#   - If not installed: brew install

install_modern_cli_macos() {
    log_step "Modern CLI stack (macOS)"

    if need brew; then
        log_warn "Homebrew not found — install from https://brew.sh first"
        return 1
    fi

    # All 10 tools are first-class brew formulae.
    # Notes on naming:
    #   - delta is `git-delta` in brew (binary still 'delta')
    #   - tealdeer is `tealdeer` in brew (provides 'tldr' command)
    local pkgs=(
        bat
        eza
        fd
        ripgrep
        dust
        duf
        btop
        sd
        tealdeer
        git-delta
    )

    # One-time brew update so we have the latest formulae
    brew update >/dev/null 2>&1 || log_warn "brew update failed (continuing)"

    for pkg in "${pkgs[@]}"; do
        if brew list --formula "$pkg" >/dev/null 2>&1; then
            # Installed — try upgrading
            if brew outdated --formula "$pkg" >/dev/null 2>&1; then
                # Outdated — upgrade
                if brew upgrade "$pkg" >/dev/null 2>&1; then
                    log_info "$pkg upgraded"
                else
                    log_warn "$pkg upgrade failed"
                fi
            else
                log_skip "$pkg (already at latest)"
            fi
        else
            if brew install "$pkg" >/dev/null 2>&1; then
                log_info "$pkg installed"
            else
                log_warn "$pkg install failed (continuing)"
            fi
        fi
    done

    # tealdeer needs cache populated before first use
    if have tldr; then
        tldr --update 2>/dev/null || true
    fi
}
