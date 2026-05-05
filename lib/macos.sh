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
        # Round 1: modern CLI stack
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
        # Round 2: shell-integration tools
        fzf
        zoxide
        direnv
        atuin
        # Round 3: workflow & polish (font added separately via cask)
        lazygit
        zellij
        mise
        pnpm
        # Round 5: prompt
        starship
        # Round 8: editor (used as $EDITOR in shell/zshrc)
        micro
        # Round 9: GitHub CLI (also enables gh-dash, gh-poi extensions below)
        gh
    )

    # One-time brew update so we have the latest formulae
    brew update >/dev/null 2>&1 || log_warn "brew update failed (continuing)"

    for pkg in "${pkgs[@]}"; do
        if brew list --formula "$pkg" >/dev/null 2>&1; then
            # Installed — check if outdated (brew outdated exits 0 either way;
            # it prints the package name only when an update is available).
            if [ -n "$(brew outdated --formula "$pkg" 2>/dev/null)" ]; then
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

    # Round 4: Ghostty terminal emulator (cask)
    if ! brew list --cask ghostty >/dev/null 2>&1; then
        if brew install --cask ghostty >/dev/null 2>&1; then
            log_info "Ghostty installed (cask)"
        else
            log_warn "Ghostty install failed (try: brew install --cask ghostty manually)"
        fi
    else
        # Already installed — check if outdated
        if [ -n "$(brew outdated --cask ghostty 2>/dev/null)" ]; then
            brew upgrade --cask ghostty >/dev/null 2>&1 \
                && log_info "Ghostty upgraded" \
                || log_warn "Ghostty upgrade failed"
        else
            log_skip "Ghostty (cask, already at latest)"
        fi
    fi

    # Round 3: JetBrainsMono Nerd Font via brew cask
    if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
        if brew install --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
            log_info "JetBrainsMono Nerd Font installed (cask)"
        else
            log_warn "JetBrainsMono Nerd Font install failed (try: brew tap homebrew/cask-fonts)"
        fi
    else
        log_skip "JetBrainsMono Nerd Font (cask, already installed)"
    fi

    # Round 3: gh extensions
    install_gh_extensions || log_warn "gh extensions install had issues (continuing)"

    # Round 3: zsh plugins
    install_zsh_plugins   || log_warn "zsh plugins install had issues (continuing)"
}

# Shared helpers (used by both linux.sh and macos.sh — defined here for macos
# since linux.sh defines its own). Both files source common.sh; keep these
# functions OUT of common.sh because they're install-specific (need the
# full install context).

install_gh_extensions() {
    if ! command -v gh >/dev/null 2>&1; then
        log_skip "gh extensions (gh CLI not installed)"
        return 0
    fi
    log_step "gh extensions"
    local extensions=("dlvhdr/gh-dash" "mislav/gh-poi")
    local installed_exts
    installed_exts="$(gh extension list 2>/dev/null || true)"
    for ext in "${extensions[@]}"; do
        if printf '%s\n' "$installed_exts" | grep -q "$ext"; then
            log_skip "gh ext $ext (already installed)"
        else
            gh extension install "$ext" >/dev/null 2>&1 \
                && log_info "gh ext $ext installed" \
                || log_warn "gh ext $ext install failed"
        fi
    done
}

install_zsh_plugins() {
    log_step "Zsh plugins"
    local plugin_dir="$HOME/.local/share/zsh-plugins"
    mkdir -p "$plugin_dir"
    local plugins=("zsh-users/zsh-autosuggestions" "zsh-users/zsh-syntax-highlighting" "zsh-users/zsh-completions")
    for repo in "${plugins[@]}"; do
        local name="${repo##*/}"
        local target="$plugin_dir/$name"
        if [ -d "$target/.git" ]; then
            (cd "$target" && git pull --quiet 2>/dev/null) \
                && log_info "$name (updated)" \
                || log_warn "$name update failed"
        else
            git clone --quiet --depth 1 "https://github.com/$repo.git" "$target" \
                && log_info "$name cloned" \
                || log_warn "$name clone failed"
        fi
    done
}
