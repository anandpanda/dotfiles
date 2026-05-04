#!/bin/bash
# Linux (Debian/Ubuntu) tool installs.
# Strategy per tool: apt where available; static binary from GitHub releases otherwise.
# All installers are upgrade-aware:
#   - apt path: `apt-get install -y` is idempotent and upgrades when a newer
#     candidate is available (after `apt-get update`).
#   - gh_install path: compares latest release tag with installed version and
#     skips if already at latest.

# Per-tool installers — each is independently runnable + idempotent + upgrade-aware.

install_bat_linux() {
    if apt_has bat; then
        sudo apt-get install -y -q bat \
            && log_info "bat (apt up-to-date or upgraded)" \
            || log_warn "bat apt install failed"
        # On Debian/Ubuntu the binary is 'batcat' due to a name clash; symlink it
        if have batcat && ! have bat; then
            mkdir -p "$BIN_DIR"
            ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
            log_info "Linked batcat → $BIN_DIR/bat"
        fi
    else
        gh_install sharkdp/bat "${ARCH}-unknown-linux-musl.tar.gz" bat
    fi
}

install_eza_linux() {
    if apt_has eza; then
        sudo apt-get install -y -q eza \
            && log_info "eza (apt up-to-date or upgraded)" \
            || log_warn "eza apt install failed"
    else
        gh_install eza-community/eza "${ARCH}-unknown-linux-gnu.tar.gz" eza
    fi
}

install_fd_linux() {
    if apt_has fd-find; then
        sudo apt-get install -y -q fd-find \
            && log_info "fd (apt up-to-date or upgraded)" \
            || log_warn "fd apt install failed"
        if have fdfind && ! have fd; then
            mkdir -p "$BIN_DIR"
            ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
            log_info "Linked fdfind → $BIN_DIR/fd"
        fi
    else
        gh_install sharkdp/fd "${ARCH}-unknown-linux-musl.tar.gz" fd
    fi
}

install_ripgrep_linux() {
    if apt_has ripgrep; then
        sudo apt-get install -y -q ripgrep \
            && log_info "ripgrep (apt up-to-date or upgraded)" \
            || log_warn "ripgrep apt install failed"
    else
        gh_install BurntSushi/ripgrep "${ARCH}-unknown-linux-musl.tar.gz" rg
    fi
}

install_dust_linux() {
    # 'du-dust' only landed in Ubuntu 25.04+; prefer GitHub binary on LTS releases
    if apt_has du-dust; then
        sudo apt-get install -y -q du-dust \
            && log_info "dust (apt up-to-date or upgraded)" \
            || log_warn "dust apt install failed"
    else
        gh_install bootandy/dust "${ARCH}-unknown-linux-musl.tar.gz" dust
    fi
}

install_duf_linux() {
    if apt_has duf; then
        sudo apt-get install -y -q duf \
            && log_info "duf (apt up-to-date or upgraded)" \
            || log_warn "duf apt install failed"
    else
        gh_install muesli/duf "linux_${ARCH/x86_64/amd64}.deb" duf
    fi
}

install_btop_linux() {
    if apt_has btop; then
        sudo apt-get install -y -q btop \
            && log_info "btop (apt up-to-date or upgraded)" \
            || log_warn "btop apt install failed"
    else
        # btop's release asset name: btop-x86_64-unknown-linux-musl.tar.gz
        gh_install aristocratos/btop "btop-${ARCH}-unknown-linux-musl.tar.gz" btop
    fi
}

install_sd_linux() {
    if apt_has sd; then
        sudo apt-get install -y -q sd \
            && log_info "sd (apt up-to-date or upgraded)" \
            || log_warn "sd apt install failed"
    else
        gh_install chmln/sd "${ARCH}-unknown-linux-musl.tar.gz" sd
    fi
}

install_tealdeer_linux() {
    # tealdeer provides the 'tldr' command — fast Rust client (vs the Node tldr)
    if apt_has tealdeer; then
        sudo apt-get install -y -q tealdeer \
            && log_info "tealdeer (apt up-to-date or upgraded)" \
            || log_warn "tealdeer apt install failed"
    else
        # tealdeer ships bare binaries (no archive). Asset: tealdeer-linux-x86_64-musl
        # Pattern uses $ anchor against the URL itself (not the JSON line).
        gh_install tealdeer-rs/tealdeer "tealdeer-linux-${ARCH}-musl$" tldr
    fi
    # Ensure the cache is populated (one-time per machine)
    have tldr && tldr --update 2>/dev/null || true
}

install_delta_linux() {
    if apt_has git-delta; then
        sudo apt-get install -y -q git-delta \
            && log_info "delta (apt up-to-date or upgraded)" \
            || log_warn "delta apt install failed"
    else
        # delta uses 'gnu' (not 'musl') in release tarballs
        gh_install dandavison/delta "${ARCH}-unknown-linux-gnu.tar.gz" delta
    fi
}

# Round 2: shell-integration tools

install_fzf_linux() {
    if apt_has fzf; then
        sudo apt-get install -y -q fzf \
            && log_info "fzf (apt up-to-date or upgraded)" \
            || log_warn "fzf apt install failed"
    else
        gh_install junegunn/fzf "fzf-.*-linux_amd64.tar.gz" fzf
    fi
}

install_zoxide_linux() {
    if apt_has zoxide; then
        sudo apt-get install -y -q zoxide \
            && log_info "zoxide (apt up-to-date or upgraded)" \
            || log_warn "zoxide apt install failed"
    else
        gh_install ajeetdsouza/zoxide "zoxide-.*-${ARCH}-unknown-linux-musl.tar.gz" zoxide
    fi
}

install_direnv_linux() {
    if apt_has direnv; then
        sudo apt-get install -y -q direnv \
            && log_info "direnv (apt up-to-date or upgraded)" \
            || log_warn "direnv apt install failed"
    else
        # direnv ships bare binaries: direnv.linux-amd64
        gh_install direnv/direnv "direnv\.linux-${ARCH/x86_64/amd64}$" direnv
    fi
}

install_atuin_linux() {
    if apt_has atuin; then
        sudo apt-get install -y -q atuin \
            && log_info "atuin (apt up-to-date or upgraded)" \
            || log_warn "atuin apt install failed"
    else
        gh_install atuinsh/atuin "atuin-${ARCH}-unknown-linux-musl.tar.gz" atuin
    fi
}

# Round 3: workflow & polish bundle

install_lazygit_linux() {
    if apt_has lazygit; then
        sudo apt-get install -y -q lazygit \
            && log_info "lazygit (apt up-to-date or upgraded)" \
            || log_warn "lazygit apt install failed"
    else
        # lazygit asset: lazygit_<ver>_linux_x86_64.tar.gz (lowercase 'linux')
        gh_install jesseduffield/lazygit "lazygit_.*_linux_${ARCH}\\.tar\\.gz$" lazygit
    fi
}

install_zellij_linux() {
    if apt_has zellij; then
        sudo apt-get install -y -q zellij \
            && log_info "zellij (apt up-to-date or upgraded)" \
            || log_warn "zellij apt install failed"
    else
        # zellij asset: zellij-x86_64-unknown-linux-musl.tar.gz
        gh_install zellij-org/zellij "zellij-${ARCH}-unknown-linux-musl.tar.gz" zellij
    fi
}

install_mise_linux() {
    if apt_has mise; then
        sudo apt-get install -y -q mise \
            && log_info "mise (apt up-to-date or upgraded)" \
            || log_warn "mise apt install failed"
    else
        # mise asset: mise-v<ver>-linux-x64.tar.gz (note: x64 not x86_64)
        gh_install jdx/mise "mise-v.*-linux-${ARCH/x86_64/x64}\.tar\.gz$" mise
    fi
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
        # corepack enable creates a shim at /usr/bin/pnpm — needs sudo.
        # First pnpm invocation will download pnpm itself (one-time, ~5MB).
        if sudo corepack enable pnpm 2>/dev/null; then
            log_info "pnpm enabled via corepack (first run will download pnpm)"
            return 0
        fi
        log_warn "corepack enable pnpm failed (try: sudo corepack enable pnpm)"
        return 1
    fi
    if apt_has pnpm; then
        sudo apt-get install -y -q pnpm 2>/dev/null \
            && log_info "pnpm (apt up-to-date or upgraded)" \
            || log_warn "pnpm apt install failed"
        return $?
    fi
    log_warn "pnpm: install Node first (try 'mise use -g node@lts'), then re-run install.sh"
}

# Install gh CLI extensions (no-op if gh not installed; idempotent — gh skips already-installed)
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
    # No apt package on Ubuntu 22.04/24.04; static binary from GitHub.
    gh_install starship/starship "starship-${ARCH}-unknown-linux-musl.tar.gz" starship
}

install_micro_linux() {
    # micro — modern non-modal CLI editor; Ctrl+S/C/V like every other app.
    # Used as $EDITOR in shell/zshrc. Available in apt since Ubuntu 22.04+.
    if apt_has micro; then
        sudo apt-get install -y -q micro \
            && log_info "micro (apt up-to-date or upgraded)" \
            || log_warn "micro apt install failed"
    else
        # GitHub release asset: micro-<ver>-linux64.tgz (or linux-arm64.tgz)
        case "$ARCH" in
            x86_64) gh_install zyedidia/micro "micro-.*-linux64\.tgz$" micro ;;
            aarch64) gh_install zyedidia/micro "micro-.*-linux-arm64\.tgz$" micro ;;
            *) log_warn "micro: unsupported arch $ARCH, skipping" ;;
        esac
    fi
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

    # Refresh apt cache once before all installs (improves apt_has + ensures upgrades)
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq 2>/dev/null || log_warn "apt-get update failed (continuing)"
    fi

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
    install_gh_extensions   || log_warn "gh extensions install had issues (continuing)"
    install_nerd_font_linux || log_warn "Nerd Font install had issues (continuing)"
    install_zsh_plugins     || log_warn "zsh plugins install had issues (continuing)"

    # Round 5: Prompt
    install_starship_linux  || log_warn "starship install had issues (continuing)"

    # Round 8: Editor (used as $EDITOR in shell/zshrc)
    install_micro_linux     || log_warn "micro install had issues (continuing)"

    # Round 4: Ghostty (GUI app — skip on Linux, hint only)
    # No official .deb/apt; flatpak works on desktop Linux but not in headless
    # containers. Config still ships via configs/ghostty/ for use on macOS or
    # Linux desktops where the user installs Ghostty themselves.
    log_skip "Ghostty (GUI terminal — install via flathub on desktop Linux: flatpak install flathub com.mitchellh.ghostty)"
}
