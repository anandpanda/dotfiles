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
        sudo apt-get install -y -q bat >/dev/null 2>&1 \
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
        sudo apt-get install -y -q eza >/dev/null 2>&1 \
            && log_info "eza (apt up-to-date or upgraded)" \
            || log_warn "eza apt install failed"
    else
        gh_install eza-community/eza "${ARCH}-unknown-linux-gnu.tar.gz" eza
    fi
}

install_fd_linux() {
    if apt_has fd-find; then
        sudo apt-get install -y -q fd-find >/dev/null 2>&1 \
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
        sudo apt-get install -y -q ripgrep >/dev/null 2>&1 \
            && log_info "ripgrep (apt up-to-date or upgraded)" \
            || log_warn "ripgrep apt install failed"
    else
        gh_install BurntSushi/ripgrep "${ARCH}-unknown-linux-musl.tar.gz" rg
    fi
}

install_dust_linux() {
    # 'du-dust' only landed in Ubuntu 25.04+; prefer GitHub binary on LTS releases
    if apt_has du-dust; then
        sudo apt-get install -y -q du-dust >/dev/null 2>&1 \
            && log_info "dust (apt up-to-date or upgraded)" \
            || log_warn "dust apt install failed"
    else
        gh_install bootandy/dust "${ARCH}-unknown-linux-musl.tar.gz" dust
    fi
}

install_duf_linux() {
    if apt_has duf; then
        sudo apt-get install -y -q duf >/dev/null 2>&1 \
            && log_info "duf (apt up-to-date or upgraded)" \
            || log_warn "duf apt install failed"
    else
        gh_install muesli/duf "linux_${ARCH/x86_64/amd64}.deb" duf
    fi
}

install_btop_linux() {
    if apt_has btop; then
        sudo apt-get install -y -q btop >/dev/null 2>&1 \
            && log_info "btop (apt up-to-date or upgraded)" \
            || log_warn "btop apt install failed"
    else
        # btop's release asset name: btop-x86_64-unknown-linux-musl.tar.gz
        gh_install aristocratos/btop "btop-${ARCH}-unknown-linux-musl.tar.gz" btop
    fi
}

install_sd_linux() {
    if apt_has sd; then
        sudo apt-get install -y -q sd >/dev/null 2>&1 \
            && log_info "sd (apt up-to-date or upgraded)" \
            || log_warn "sd apt install failed"
    else
        gh_install chmln/sd "${ARCH}-unknown-linux-musl.tar.gz" sd
    fi
}

install_tealdeer_linux() {
    # tealdeer provides the 'tldr' command — fast Rust client (vs the Node tldr)
    if apt_has tealdeer; then
        sudo apt-get install -y -q tealdeer >/dev/null 2>&1 \
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
        sudo apt-get install -y -q git-delta >/dev/null 2>&1 \
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
        sudo apt-get install -y -q fzf >/dev/null 2>&1 \
            && log_info "fzf (apt up-to-date or upgraded)" \
            || log_warn "fzf apt install failed"
    else
        gh_install junegunn/fzf "fzf-.*-linux_amd64.tar.gz" fzf
    fi
}

install_zoxide_linux() {
    if apt_has zoxide; then
        sudo apt-get install -y -q zoxide >/dev/null 2>&1 \
            && log_info "zoxide (apt up-to-date or upgraded)" \
            || log_warn "zoxide apt install failed"
    else
        gh_install ajeetdsouza/zoxide "zoxide-.*-${ARCH}-unknown-linux-musl.tar.gz" zoxide
    fi
}

install_direnv_linux() {
    if apt_has direnv; then
        sudo apt-get install -y -q direnv >/dev/null 2>&1 \
            && log_info "direnv (apt up-to-date or upgraded)" \
            || log_warn "direnv apt install failed"
    else
        # direnv ships bare binaries: direnv.linux-amd64
        gh_install direnv/direnv "direnv\.linux-${ARCH/x86_64/amd64}$" direnv
    fi
}

install_atuin_linux() {
    if apt_has atuin; then
        sudo apt-get install -y -q atuin >/dev/null 2>&1 \
            && log_info "atuin (apt up-to-date or upgraded)" \
            || log_warn "atuin apt install failed"
    else
        gh_install atuinsh/atuin "atuin-${ARCH}-unknown-linux-musl.tar.gz" atuin
    fi
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
}
