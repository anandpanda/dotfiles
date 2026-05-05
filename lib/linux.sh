#!/bin/bash
# Linux (Debian/Ubuntu) tool installs.
#
# Strategy: install everything from upstream GitHub releases via gh_install,
# not apt. Reasons:
#   - Ubuntu LTS lags upstream by months/years (e.g. 24.04 ships fzf 0.44.1
#     while upstream is 0.72+). Config knobs added post-LTS-cut silently
#     break against the apt build.
#   - Mac uses Homebrew which tracks upstream — Linux on gh_install matches.
#   - One install path = one mental model. No apt-vs-gh divergence per tool.
#
# gh_install is upgrade-aware: compares the installed version against the
# latest release tag and skips the download when already current.
#
# system-package essentials (jq, zsh, curl, unzip, …) are still installed
# via apt from install.sh's "Step 1: System dependencies" — those are stable
# and don't drift fast enough to matter.

# Per-tool installers — each is independently runnable + idempotent + upgrade-aware.

install_bat_linux() {
    gh_install sharkdp/bat "${ARCH}-unknown-linux-musl.tar.gz" bat
}

install_eza_linux() {
    gh_install eza-community/eza "${ARCH}-unknown-linux-gnu.tar.gz" eza
}

install_fd_linux() {
    gh_install sharkdp/fd "${ARCH}-unknown-linux-musl.tar.gz" fd
}

install_ripgrep_linux() {
    gh_install BurntSushi/ripgrep "${ARCH}-unknown-linux-musl.tar.gz" rg
}

install_dust_linux() {
    gh_install bootandy/dust "${ARCH}-unknown-linux-musl.tar.gz" dust
}

install_duf_linux() {
    gh_install muesli/duf "linux_${ARCH/x86_64/amd64}.deb" duf
}

install_btop_linux() {
    # release asset: btop-x86_64-unknown-linux-musl.tar.gz
    gh_install aristocratos/btop "btop-${ARCH}-unknown-linux-musl.tar.gz" btop
}

install_sd_linux() {
    gh_install chmln/sd "${ARCH}-unknown-linux-musl.tar.gz" sd
}

install_tealdeer_linux() {
    # tealdeer provides the 'tldr' command — fast Rust client (vs the Node tldr).
    # Ships bare binaries (no archive); pattern uses $ anchor against the URL.
    gh_install tealdeer-rs/tealdeer "tealdeer-linux-${ARCH}-musl$" tldr
    have tldr && tldr --update 2>/dev/null || true
}

install_delta_linux() {
    # delta uses 'gnu' (not 'musl') in release tarballs
    gh_install dandavison/delta "${ARCH}-unknown-linux-gnu.tar.gz" delta
}

# Round 2: shell-integration tools

install_fzf_linux() {
    gh_install junegunn/fzf "fzf-.*-linux_amd64.tar.gz" fzf
}

install_zoxide_linux() {
    gh_install ajeetdsouza/zoxide "zoxide-.*-${ARCH}-unknown-linux-musl.tar.gz" zoxide
}

install_direnv_linux() {
    # direnv ships bare binaries: direnv.linux-amd64
    gh_install direnv/direnv "direnv\.linux-${ARCH/x86_64/amd64}$" direnv
}

install_atuin_linux() {
    gh_install atuinsh/atuin "atuin-${ARCH}-unknown-linux-musl.tar.gz" atuin
}

# Round 3: workflow & polish bundle

install_lazygit_linux() {
    # asset: lazygit_<ver>_linux_x86_64.tar.gz (lowercase 'linux')
    gh_install jesseduffield/lazygit "lazygit_.*_linux_${ARCH}\\.tar\\.gz$" lazygit
}

install_zellij_linux() {
    gh_install zellij-org/zellij "zellij-${ARCH}-unknown-linux-musl.tar.gz" zellij
}

install_mise_linux() {
    # asset: mise-v<ver>-linux-x64.tar.gz (note: x64 not x86_64)
    gh_install jdx/mise "mise-v.*-linux-${ARCH/x86_64/x64}\.tar\.gz$" mise
}

install_pnpm_linux() {
    # pnpm needs Node + corepack. The standalone tarball has a multi-file
    # structure (binary + dist/) that doesn't drop cleanly via gh_install.
    # Instead, rely on corepack (ships with Node 16+) to manage pnpm.
    if have pnpm; then
        log_skip "pnpm (already on PATH)"
        return 0
    fi
    if have corepack; then
        if sudo corepack enable pnpm 2>/dev/null; then
            log_info "pnpm enabled via corepack (first run will download pnpm)"
            return 0
        fi
        log_warn "corepack enable pnpm failed (try: sudo corepack enable pnpm)"
        return 1
    fi
    log_warn "pnpm: install Node first (try 'mise use -g node@lts'), then re-run install.sh"
}

# Install gh CLI extensions (no-op if gh not installed; idempotent)
install_gh_extensions() {
    if ! command -v gh >/dev/null 2>&1; then
        log_skip "gh extensions (gh CLI not installed)"
        return 0
    fi
    log_step "gh extensions"
    local extensions=(
        "dlvhdr/gh-dash"      # PR/issue dashboard
        "mislav/gh-poi"       # cleanup merged branches
    )
    local installed_exts
    installed_exts="$(gh extension list 2>/dev/null || true)"
    for ext in "${extensions[@]}"; do
        if printf '%s\n' "$installed_exts" | grep -q "$ext"; then
            log_skip "gh ext $ext (already installed)"
        else
            gh extension install "$ext" \
                && log_info "gh ext $ext installed" \
                || log_warn "gh ext $ext install failed"
        fi
    done
}

install_starship_linux() {
    gh_install starship/starship "starship-${ARCH}-unknown-linux-musl.tar.gz" starship
}

install_gh_linux() {
    # GitHub CLI. Use the .deb to get man pages and shell completions
    # alongside the binary; Ubuntu's apt 'gh' package itself comes from a
    # third-party repo that has to be wired up separately, so going direct
    # to the upstream .deb is simpler. gh_install dispatches .deb via dpkg.
    gh_install cli/cli "gh_.*_linux_${ARCH/x86_64/amd64}\.deb$" gh
}

install_micro_linux() {
    # micro — modern non-modal CLI editor; Ctrl+S/C/V like every other app.
    # Used as $EDITOR in shell/zshrc. Prefer the -static build for portability.
    case "$ARCH" in
        x86_64)  gh_install zyedidia/micro "micro-.*-linux64-static\.tar\.gz$" micro ;;
        aarch64) gh_install zyedidia/micro "micro-.*-linux-arm64\.tar\.gz$"   micro ;;
        *) log_warn "micro: unsupported arch $ARCH, skipping" ;;
    esac
}

# Install JetBrainsMono Nerd Font into ~/.local/share/fonts/
install_nerd_font_linux() {
    local font_dir="$HOME/.local/share/fonts"
    local marker="$font_dir/.jetbrainsmono-nerd-installed"
    if [ -f "$marker" ]; then
        log_skip "JetBrainsMono Nerd Font (already installed)"
        return 0
    fi
    log_step "JetBrainsMono Nerd Font"
    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o "$tmp/JBMono.zip"; then
        if command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$tmp/JBMono.zip" -d "$font_dir" "*.ttf"
            command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$font_dir" >/dev/null 2>&1
            touch "$marker"
            log_info "JetBrainsMono Nerd Font installed to $font_dir"
        else
            log_warn "unzip not installed — install with: sudo apt install unzip"
        fi
    else
        log_warn "Nerd Font download failed"
    fi
    rm -rf "$tmp"
}

# Install zsh plugins (clone to ~/.local/share/zsh-plugins/<name>/)
install_zsh_plugins() {
    log_step "Zsh plugins"
    local plugin_dir="$HOME/.local/share/zsh-plugins"
    mkdir -p "$plugin_dir"
    local plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-completions"
    )
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

# Orchestrator — runs all per-tool installers, tolerates individual failures.
install_modern_cli_linux() {
    log_step "Modern CLI stack (Linux)"

    install_bat_linux       || log_warn "bat install had issues (continuing)"
    install_eza_linux       || log_warn "eza install had issues (continuing)"
    install_fd_linux        || log_warn "fd install had issues (continuing)"
    install_ripgrep_linux   || log_warn "ripgrep install had issues (continuing)"
    install_dust_linux      || log_warn "dust install had issues (continuing)"
    install_duf_linux       || log_warn "duf install had issues (continuing)"
    install_btop_linux      || log_warn "btop install had issues (continuing)"
    install_sd_linux        || log_warn "sd install had issues (continuing)"
    install_tealdeer_linux  || log_warn "tealdeer install had issues (continuing)"
    install_delta_linux     || log_warn "delta install had issues (continuing)"

    # Round 2: shell-integration tools
    install_fzf_linux       || log_warn "fzf install had issues (continuing)"
    install_zoxide_linux    || log_warn "zoxide install had issues (continuing)"
    install_direnv_linux    || log_warn "direnv install had issues (continuing)"
    install_atuin_linux     || log_warn "atuin install had issues (continuing)"

    # Round 3: workflow & polish
    install_lazygit_linux   || log_warn "lazygit install had issues (continuing)"
    install_zellij_linux    || log_warn "zellij install had issues (continuing)"
    install_mise_linux      || log_warn "mise install had issues (continuing)"
    install_pnpm_linux      || log_warn "pnpm install had issues (continuing)"
    install_gh_linux        || log_warn "gh install had issues (continuing)"
    install_gh_extensions   || log_warn "gh extensions install had issues (continuing)"
    install_nerd_font_linux || log_warn "Nerd Font install had issues (continuing)"
    install_zsh_plugins     || log_warn "zsh plugins install had issues (continuing)"

    # Round 5: Prompt
    install_starship_linux  || log_warn "starship install had issues (continuing)"

    # Round 8: Editor (used as $EDITOR in shell/zshrc)
    install_micro_linux     || log_warn "micro install had issues (continuing)"

    # Round 4: Ghostty (GUI app — skip on Linux, hint only)
    log_skip "Ghostty (GUI terminal — install via flathub on desktop Linux: flatpak install flathub com.mitchellh.ghostty)"
}
