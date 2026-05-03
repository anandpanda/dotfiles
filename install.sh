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

log_step "Step 3: Wire shell aliases"

SOURCE_LINE="source $DOTFILES/shell/aliases.sh"

# Create ~/.zshrc.local if missing
[ -f "$ZSHRC_LOCAL" ] || touch "$ZSHRC_LOCAL"

if grep -qF "$SOURCE_LINE" "$ZSHRC_LOCAL" 2>/dev/null; then
    log_skip "Shell aliases already sourced from $ZSHRC_LOCAL"
else
    {
        echo ""
        echo "# dotfiles: portable shell aliases (modern CLI stack + nav + safety)"
        echo "$SOURCE_LINE"
    } >> "$ZSHRC_LOCAL"
    log_info "Appended source line to $ZSHRC_LOCAL"
fi

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
