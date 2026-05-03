#!/bin/bash
# Bootstrap portable system tooling on this machine.
# Safe to run repeatedly — fully idempotent.
#
# This script does NOT touch ~/.claude/ in any way. The contents of
# ~/dotfiles/claude/ are pure reference — deploy what you want, when you
# want, manually. See README.md for the deployment guide.
#
# Usage:
#   bash install.sh

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC_LOCAL="$HOME/.zshrc.local"

# ---------------------------------------------------------------------------
# Source shared helpers + per-OS install scripts
# ---------------------------------------------------------------------------

# shellcheck disable=SC1091
source "$DOTFILES/lib/common.sh"

OS="$(detect_os)"
case "$OS" in
    linux|macos) source "$DOTFILES/lib/$OS.sh" ;;
    *)           echo "Unsupported OS: $OS — aborting." >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

echo "==> Bootstrapping portable system tooling"
echo "    DOTFILES = $DOTFILES"
echo "    OS       = $OS"
echo "    NOTE     = This script will NOT touch ~/.claude/. Use it as you wish."

# ---------------------------------------------------------------------------
# 1. System dependencies (jq required, gh + uv + semgrep auto-installed)
# ---------------------------------------------------------------------------

log_step "Step 1: System dependencies"

if need jq; then
    log_err "jq missing — install via your package manager:"
    echo   "        Linux: sudo apt install -y jq"
    echo   "        Mac:   brew install jq"
    echo   "      Then re-run this script."
    exit 1
fi
log_info "jq"

if need gh; then
    log_warn "gh CLI missing (optional)"
    echo   "        Linux: sudo apt install -y gh"
    echo   "        Mac:   brew install gh"
else
    log_info "gh"
fi

if need uv; then
    echo "    Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
log_info "uv ($(uv --version 2>/dev/null | head -1))"

if need semgrep; then
    echo "    Installing semgrep via uv..."
    uv tool install semgrep
fi
log_info "semgrep ($(semgrep --version 2>/dev/null | head -1))"

# ---------------------------------------------------------------------------
# 2. Modern CLI stack (Round 1)
# ---------------------------------------------------------------------------

case "$OS" in
    linux) install_modern_cli_linux ;;
    macos) install_modern_cli_macos ;;
esac

# ---------------------------------------------------------------------------
# 3. Wire shell aliases into ~/.zshrc.local
# ---------------------------------------------------------------------------

log_step "Step 3: Wire shell init + aliases"

SOURCE_INIT="source $DOTFILES/shell/init.sh"
SOURCE_ALIASES="source $DOTFILES/shell/aliases.sh"

# Create ~/.zshrc.local if missing
[ -f "$ZSHRC_LOCAL" ] || touch "$ZSHRC_LOCAL"

# Source init.sh BEFORE aliases.sh — init defines functions/keybindings that
# may be referenced by aliases or follow-on tools.
header_added=false
for line in "$SOURCE_INIT" "$SOURCE_ALIASES"; do
    name="$(basename "${line##* }")"
    if grep -qF "$line" "$ZSHRC_LOCAL" 2>/dev/null; then
        log_skip "$name already sourced from $ZSHRC_LOCAL"
    else
        if ! $header_added; then
            echo "" >> "$ZSHRC_LOCAL"
            echo "# dotfiles: shell integrations + portable aliases" >> "$ZSHRC_LOCAL"
            header_added=true
        fi
        echo "$line" >> "$ZSHRC_LOCAL"
        log_info "Appended source for $name to $ZSHRC_LOCAL"
    fi
done

# Ensure ~/.zshrc itself sources ~/.zshrc.local on bare systems
ZSHRC="$HOME/.zshrc"
ZSHRC_LOCAL_SOURCE='[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
if [ -f "$ZSHRC" ] && ! grep -qF '.zshrc.local' "$ZSHRC" 2>/dev/null; then
    {
        echo ""
        echo "# dotfiles: source machine-local shell extensions"
        echo "$ZSHRC_LOCAL_SOURCE"
    } >> "$ZSHRC"
    log_info "Added .zshrc.local sourcing to $ZSHRC"
fi

# ---------------------------------------------------------------------------
# 4. Symlink tool configs into ~/.config/
# ---------------------------------------------------------------------------
# Each subdir of $DOTFILES/configs/ maps to ~/.config/<tool>/.
# We symlink the directory, so edits to ~/.config/<tool>/<file> flow back
# to the dotfiles repo automatically.

log_step "Step 4: Deploy tool configs (~/.config symlinks)"

CONFIG_SRC="$DOTFILES/configs"
CONFIG_DST="$HOME/.config"
mkdir -p "$CONFIG_DST"

if [ -d "$CONFIG_SRC" ]; then
    for tool_dir in "$CONFIG_SRC"/*/; do
        [ -d "$tool_dir" ] || continue
        tool="$(basename "$tool_dir")"
        target="$CONFIG_DST/$tool"

        # If target is already the right symlink, skip
        if [ -L "$target" ] && [ "$(readlink "$target")" = "${tool_dir%/}" ]; then
            log_skip "$tool config (already symlinked)"
            continue
        fi

        # If target exists as a real directory, back it up before linking
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
            mv "$target" "$backup"
            log_warn "$tool: existing $target moved to $backup"
        fi

        ln -sfn "${tool_dir%/}" "$target"
        log_info "$tool config symlinked → $target"
    done
else
    log_skip "configs/ directory missing — nothing to deploy"
fi

# ---------------------------------------------------------------------------
# 5. atuin: backfill existing shell history (one-time per machine)
# ---------------------------------------------------------------------------
# `atuin import auto` reads ~/.zsh_history (or bash equivalent) and stamps
# every command into atuin's sqlite db. Idempotent on subsequent runs only
# via a sentinel file — atuin itself doesn't track "already imported", and
# re-running causes duplicates. Sentinel lives in atuin's data dir so it
# travels with the db.

log_step "Step 5: atuin history backfill"

ATUIN_DATA="$HOME/.local/share/atuin"
ATUIN_SENTINEL="$ATUIN_DATA/.imported-by-dotfiles"

if ! command -v atuin >/dev/null 2>&1; then
    log_skip "atuin not installed — skipping import"
elif [ -f "$ATUIN_SENTINEL" ]; then
    log_skip "atuin history already imported (sentinel: $ATUIN_SENTINEL)"
elif [ ! -f "$HOME/.zsh_history" ] && [ ! -f "$HOME/.bash_history" ]; then
    log_skip "no shell history file found — nothing to import"
else
    if atuin import auto >/dev/null 2>&1; then
        mkdir -p "$ATUIN_DATA"
        touch "$ATUIN_SENTINEL"
        log_info "atuin: imported existing shell history"
    else
        log_warn "atuin import failed (continuing — re-try manually with 'atuin import auto')"
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log_step "Done."
echo ""
echo "Next steps:"
echo ""
echo "  System tooling: ✅ ready"
echo "  Modern CLI:     ✅ ready (open a fresh shell to pick up aliases)"
echo ""
echo "  Claude Code config: ~/dotfiles/claude/ is pure reference."
echo "    Deploy what you want manually. See README.md for the guide."
echo "    TL;DR for symlinking everything:"
echo ""
echo "      mkdir -p ~/.claude/hooks"
echo "      for f in $DOTFILES/claude/hooks/*.sh; do"
echo "          ln -sf \"\$f\" ~/.claude/hooks/\$(basename \"\$f\")"
echo "      done"
echo "      ln -sf $DOTFILES/claude/statusline.sh ~/.claude/statusline.sh"
echo "      sed \"s|__HOME__|\$HOME|g\" $DOTFILES/claude/settings.template.json > ~/.claude/settings.json"
echo ""
echo "    For CLAUDE.md and memory: review ~/dotfiles/claude/CLAUDE.md and"
echo "    ~/dotfiles/claude/memory/, then merge/copy what you want."
