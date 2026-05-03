# Shell-integration evals — tool hooks that need shell-side wiring.
# Sourced by ~/.zshrc.local BEFORE shell/aliases.sh.
# Each integration uses `command -v` guards so missing tools degrade silently.

# =============================================================================
# fzf — fuzzy finder (Ctrl-R history, Ctrl-T file picker, Alt-C cd picker)
# =============================================================================
if command -v fzf >/dev/null 2>&1; then
    if fzf --help 2>&1 | grep -q -- '--zsh'; then
        # Modern fzf (>= 0.48): one command emits keybindings + completion
        source <(fzf --zsh)
    elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
        # Older Debian/Ubuntu fzf packages ship integration files separately
        source /usr/share/doc/fzf/examples/key-bindings.zsh
        [ -f /usr/share/doc/fzf/examples/completion.zsh ] && \
            source /usr/share/doc/fzf/examples/completion.zsh
    fi
fi

# =============================================================================
# zoxide — smart cd with frecent-dir learning
# After this, `z <pattern>` jumps to your most-visited matching dir;
# `zi <pattern>` opens fzf-powered interactive picker.
# =============================================================================
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# =============================================================================
# direnv — auto-load .envrc per directory
# Per-directory env vars; requires `direnv allow` in each .envrc dir.
# =============================================================================
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# =============================================================================
# atuin — sqlite-backed history (records + sync); fzf KEEPS Ctrl-R
# We disable atuin's Ctrl-R + up-arrow bindings deliberately:
#   - Daily Ctrl-R: fzf is faster and less disruptive
#   - For archival/cross-device search: run `atuin search` explicitly
# atuin still records every command to sqlite + syncs (if registered).
# =============================================================================
command -v atuin >/dev/null 2>&1 && \
    eval "$(atuin init zsh --disable-ctrl-r --disable-up-arrow)"
