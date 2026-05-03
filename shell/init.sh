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

# =============================================================================
# mise — runtime version manager (Python/Node/Go/etc.)
# Activates per-shell; respects .mise.toml / .tool-versions in cwd.
# =============================================================================
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# =============================================================================
# Zsh plugins — autosuggestions, syntax-highlighting, completions
# Loaded only if not already provided by another plugin manager (zinit etc.)
# Plugins live at ~/.local/share/zsh-plugins/<name>/ (cloned by install.sh)
# =============================================================================
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"

# zsh-completions: extra completion definitions (must be in fpath BEFORE compinit)
if [ -d "$ZSH_PLUGIN_DIR/zsh-completions/src" ]; then
    fpath=("$ZSH_PLUGIN_DIR/zsh-completions/src" $fpath)
fi

# zsh-autosuggestions: gray-text suggestions from history (Ctrl-F or → to accept)
# Skip if already loaded (cheerioskun's zinit may have loaded it)
if ! typeset -f _zsh_autosuggest_start >/dev/null 2>&1; then
    [ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
        source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting: command coloring as you type
# Must be sourced LAST (per its docs) — kept at end of init.sh
if ! typeset -f _zsh_highlight >/dev/null 2>&1; then
    [ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
        source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
