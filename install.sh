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
# Selective step execution. Default: run all steps.
# Pass a step name as $1 to run only that step (e.g. `bash install.sh settings`).
# ---------------------------------------------------------------------------

STEP="${1:-all}"

case "$STEP" in
    -h|--help|help)
        cat <<HELP
usage: bash install.sh [step]

Steps (run all by default):
  deps        Step 1: System dependencies (jq, gh, uv, semgrep)
  cli         Step 2: Modern CLI stack (bat, eza, fzf, starship, ...)
  shell       Step 3: Wire shell init + aliases into ~/.zshrc.local
  configs     Step 4: Symlink tool configs into ~/.config/<tool>/
  atuin       Step 5: atuin history backfill (first run only)
  extensions  Step 6: VS Code / Cursor extensions
  settings    Step 7: VS Code / Cursor user settings (deep-merge)

Workspace-scoped Claude / MCP config (NOT installed by install.sh):
  Use the standalone tool to link into a target dir (e.g. your work workspace):
    cd /path/to/your/workspace
    bash $DOTFILES/zamp-workspace/link-here.sh
  See zamp-workspace/link-here.sh for usage.

Dependencies (auto-resolved — running a step also runs its prerequisites):
  cli depends on deps
  atuin depends on cli (which depends on deps)
  shell, configs, extensions, settings have no deps

Examples:
  bash install.sh              # run all steps (default)
  bash install.sh settings     # run only Step 7 (no prereqs)
  bash install.sh atuin        # runs deps -> cli -> atuin
  bash install.sh extensions   # run only Step 6 (no prereqs)
HELP
        exit 0
        ;;
esac

# Step dependency graph. Each step's deps must run first when the step
# is requested directly. Order within "all" is the canonical sequence.
#
#   deps       (no deps — system tools jq/gh/uv/semgrep)
#   cli        ← deps      (uses jq for gh_install)
#   shell      (no deps — just appends to ~/.zshrc.local)
#   configs    (no deps — pure symlinks)
#   atuin      ← cli       (atuin binary must exist before import)
#   extensions (no deps — uses editor's own CLI)
#   settings   (no deps — uses python3 stdlib)
#
# Resolution: when user asks for step X, we run X's transitive deps first
# (in topo order), then X. Hard-coded since the graph is small + static.

case "$STEP" in
    all)        STEPS_TO_RUN=(deps cli shell configs atuin extensions settings) ;;
    deps)       STEPS_TO_RUN=(deps) ;;
    cli)        STEPS_TO_RUN=(deps cli) ;;
    shell)      STEPS_TO_RUN=(shell) ;;
    configs)    STEPS_TO_RUN=(configs) ;;
    atuin)      STEPS_TO_RUN=(deps cli atuin) ;;
    extensions) STEPS_TO_RUN=(extensions) ;;
    settings)   STEPS_TO_RUN=(settings) ;;
    *)
        echo "Error: unknown step '$STEP'." >&2
        echo "Run 'bash install.sh help' for valid step names." >&2
        exit 2
        ;;
esac

# Show resolved plan for transparency when not running "all"
if [ "$STEP" != "all" ]; then
    echo "==> Target: $STEP — running: ${STEPS_TO_RUN[*]}"
fi

should_run() {
    local step="$1"
    local s
    for s in "${STEPS_TO_RUN[@]}"; do
        [ "$s" = "$step" ] && return 0
    done
    return 1
}

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

# Hard prereq on macOS: Homebrew. Most of install.sh (Step 2 cli stack,
# Round 4 Ghostty cask, even Step 1's jq fallback) calls brew. Fail fast
# with a clear message if missing — better than a confusing 'brew: command
# not found' error halfway through.
if [ "$OS" = "macos" ] && ! command -v brew >/dev/null 2>&1; then
    cat <<'BREW_MISSING' >&2

ERROR: Homebrew is required on macOS but is not installed.

This dotfiles bootstrap calls brew throughout (CLI tools, Ghostty cask,
fonts, jq, etc.). Install Homebrew first, then re-run:

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

After install completes, follow the post-install instructions Homebrew
prints (it'll tell you to add a line to ~/.zprofile to put brew on PATH),
open a new shell, then re-run:

  bash install.sh

BREW_MISSING
    exit 1
fi

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

if should_run deps; then
log_step "Step 1: System dependencies"

# jq — auto-installed via the OS package manager if missing.
# (We still bail if brew is missing on Mac — that's a one-time user setup,
# too invasive to auto-install Homebrew silently.)
if need jq; then
    case "$OS" in
        macos)
            if need brew; then
                log_err "jq missing AND Homebrew not installed."
                echo   "  Install Homebrew first from https://brew.sh, then re-run."
                exit 1
            fi
            log_step "Installing jq via brew..."
            brew install jq >/dev/null 2>&1 || { log_err "brew install jq failed"; exit 1; }
            ;;
        linux)
            log_step "Installing jq via apt..."
            sudo apt-get update -qq 2>/dev/null
            sudo apt-get install -y -q jq >/dev/null 2>&1 || { log_err "apt install jq failed"; exit 1; }
            ;;
    esac
fi
log_info "jq ($(jq --version 2>/dev/null))"

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

fi  # end Step 1

# ---------------------------------------------------------------------------
# 2. Modern CLI stack (Round 1)
# ---------------------------------------------------------------------------

if should_run cli; then
case "$OS" in
    linux) install_modern_cli_linux ;;
    macos) install_modern_cli_macos ;;
esac
fi  # end Step 2

# ---------------------------------------------------------------------------
# 3. Wire shell aliases into ~/.zshrc.local
# ---------------------------------------------------------------------------

if should_run shell; then
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

fi  # end Step 3

# ---------------------------------------------------------------------------
# 4. Symlink tool configs into ~/.config/
# ---------------------------------------------------------------------------
# Each subdir of $DOTFILES/configs/ maps to ~/.config/<tool>/.
# We symlink the directory, so edits to ~/.config/<tool>/<file> flow back
# to the dotfiles repo automatically.

if should_run configs; then
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

fi  # end Step 4

# ---------------------------------------------------------------------------
# 5. atuin: backfill existing shell history (one-time per machine)
# ---------------------------------------------------------------------------
# `atuin import auto` reads ~/.zsh_history (or bash equivalent) and stamps
# every command into atuin's sqlite db. Idempotent on subsequent runs only
# via a sentinel file — atuin itself doesn't track "already imported", and
# re-running causes duplicates. Sentinel lives in atuin's data dir so it
# travels with the db.

if should_run atuin; then
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

fi  # end Step 5

# ---------------------------------------------------------------------------
# 6. VS Code / Cursor extensions (install + upgrade)
# ---------------------------------------------------------------------------
# Reads configs/vscode/extensions.txt — one extension ID per line, '#' = comment
# (inline or full-line). Detects which CLIs are present (`code` and/or `cursor`)
# and runs the install loop for each. Same script works on Mac (installs as
# LOCAL extensions) and on Linux/Coder (installs as REMOTE-SSH extensions);
# the CLI auto-scopes to where it runs.
#
# Idempotent: already-installed extensions are detected via --list-extensions
# and skipped silently. Bulk --update-extensions at the end upgrades anything
# outdated in a single pass.

if should_run extensions; then
log_step "Step 6: VS Code / Cursor extensions"

VSCODE_EXTS_FILE="$DOTFILES/configs/vscode/extensions.txt"

if [ ! -f "$VSCODE_EXTS_FILE" ]; then
    log_skip "$VSCODE_EXTS_FILE not found — skipping"
else
    # Detect available CLIs (one or both may exist on a machine)
    declare -a vscode_clis=()
    for cli in code cursor code-insiders; do
        command -v "$cli" >/dev/null 2>&1 && vscode_clis+=("$cli")
    done

    if [ ${#vscode_clis[@]} -eq 0 ]; then
        log_skip "No VS Code / Cursor CLI found on PATH — skipping"
    else
        # Strip comments + blank lines once into an array
        declare -a wanted_exts=()
        while IFS= read -r line; do
            ext="$(printf '%s' "$line" | awk -F'#' '{print $1}' | sed 's/[[:space:]]*$//')"
            [ -n "$ext" ] && wanted_exts+=("$ext")
        done < "$VSCODE_EXTS_FILE"

        # If `code` and `cursor` resolve to the same binary (Cursor's SSH server
        # ships both as symlinks to one cli), only run the install loop once.
        declare -A seen_realpaths=()
        declare -a unique_clis=()
        for cli in "${vscode_clis[@]}"; do
            real="$(readlink -f "$(command -v "$cli")" 2>/dev/null || command -v "$cli")"
            if [ -z "${seen_realpaths[$real]:-}" ]; then
                seen_realpaths[$real]=1
                unique_clis+=("$cli")
            fi
        done

        for cli in "${unique_clis[@]}"; do
            log_step "[$cli] installing extensions (${#wanted_exts[@]} wanted)"

            # Snapshot already-installed (lowercase for case-insensitive compare)
            installed_before="$("$cli" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

            installed_count=0
            skipped_count=0
            not_in_marketplace=0
            ui_only_refused=0
            failed_count=0
            for ext in "${wanted_exts[@]}"; do
                ext_lower="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
                if printf '%s\n' "$installed_before" | grep -qx "$ext_lower"; then
                    skipped_count=$((skipped_count + 1))
                    continue
                fi
                # Capture stderr to categorize the failure mode
                output="$("$cli" --install-extension "$ext" 2>&1)"
                if [ $? -eq 0 ] && ! printf '%s' "$output" | grep -qiE 'not found|declared to not run'; then
                    installed_count=$((installed_count + 1))
                elif printf '%s' "$output" | grep -qi 'not found'; then
                    not_in_marketplace=$((not_in_marketplace + 1))
                elif printf '%s' "$output" | grep -qi 'declared to not run'; then
                    ui_only_refused=$((ui_only_refused + 1))
                elif printf '%s' "$output" | grep -qi 'already installed'; then
                    # Edge case: CLI says "already installed" but our snapshot
                    # missed it (e.g. Cursor hides ms-python.vscode-pylance from
                    # --list-extensions because anysphere.cursorpyright wins).
                    skipped_count=$((skipped_count + 1))
                else
                    failed_count=$((failed_count + 1))
                    log_warn "[$cli] failed: $ext — $(printf '%s' "$output" | tail -1)"
                fi
            done

            log_info "[$cli] new=$installed_count, already-present=$skipped_count, failed=$failed_count"
            if [ $not_in_marketplace -gt 0 ]; then
                log_skip "[$cli] $not_in_marketplace extension(s) not in this CLI's marketplace mirror (Cursor/VS Code marketplaces differ — extensions install on whichever has them)"
            fi
            if [ $ui_only_refused -gt 0 ]; then
                log_skip "[$cli] $ui_only_refused extension(s) declared UI-only — will install on local desktop CLI, not the SSH-server one"
            fi

            # Upgrade any outdated extensions in one pass
            if "$cli" --update-extensions >/dev/null 2>&1; then
                log_info "[$cli] --update-extensions complete"
            else
                log_skip "[$cli] --update-extensions not supported on this CLI"
            fi
        done
    fi
fi

fi  # end Step 6

# ---------------------------------------------------------------------------
# 7. VS Code / Cursor user settings (deep-merge, not symlink)
# ---------------------------------------------------------------------------
# Reads configs/vscode/settings.json — our curated preferences only — and
# deep-merges into each detected user settings.json. Symlinking would clobber
# per-machine state (codesandbox project IDs, gemini project, machine-specific
# terminal profiles, theme tweaks). Merge preserves all that — only our keys
# overwrite.
#
# Coverage: VS Code + Cursor × Mac + Linux. Each (IDE, OS) settings dir we
# find gets the merge applied. Pre-merge backup at *.backup.<timestamp>.

if should_run settings; then
log_step "Step 7: VS Code / Cursor user settings (deep-merge)"

VSCODE_SETTINGS_SRC="$DOTFILES/configs/vscode/settings.json"
MERGE_HELPER="$DOTFILES/lib/merge_jsonc.py"

if [ ! -f "$VSCODE_SETTINGS_SRC" ]; then
    log_skip "$VSCODE_SETTINGS_SRC not found — skipping"
elif ! command -v python3 >/dev/null 2>&1; then
    log_warn "python3 not found — cannot deep-merge JSONC settings, skipping"
else
    # Per-IDE per-OS user settings dirs.
    # Two flavors per Linux box: desktop (when VS Code/Cursor runs natively)
    # and SSH-server (when an editor is connected remotely; the server stores
    # its own User dir under ~/.{vscode,cursor}-server/data/).
    declare -a settings_dirs=()
    case "$OS" in
        macos)
            settings_dirs=(
                "$HOME/Library/Application Support/Code/User"
                "$HOME/Library/Application Support/Cursor/User"
            )
            ;;
        linux)
            settings_dirs=(
                "$HOME/.config/Code/User"            # VS Code desktop
                "$HOME/.config/Cursor/User"          # Cursor desktop
                "$HOME/.vscode-server/data/User"     # VS Code SSH-server (remote workspace)
                "$HOME/.cursor-server/data/User"     # Cursor SSH-server (remote workspace)
            )
            ;;
    esac

    for dir in "${settings_dirs[@]}"; do
        target="$dir/settings.json"
        # Derive a friendly IDE name from the path. Desktop dirs end in
        # "/<IDE>/User"; SSH-server dirs in "/<IDE>-server/data/User".
        case "$dir" in
            *Cursor*|*cursor-server*) ide_name="Cursor" ;;
            *Code*|*vscode-server*)   ide_name="VS Code" ;;
            *)                        ide_name="$(basename "$(dirname "$dir")")" ;;
        esac
        # Append " (SSH server)" suffix to disambiguate when both desktop
        # and server dirs exist on the same machine.
        case "$dir" in
            *-server/data/User) ide_name="$ide_name (SSH server)" ;;
        esac

        if [ ! -d "$dir" ]; then
            log_skip "$ide_name not installed (no $dir)"
            continue
        fi

        if [ ! -f "$target" ]; then
            cp "$VSCODE_SETTINGS_SRC" "$target"
            log_info "$ide_name: created $target with our settings"
            continue
        fi

        backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$target" "$backup"

        if merged=$(python3 "$MERGE_HELPER" "$target" "$VSCODE_SETTINGS_SRC" 2>&1); then
            printf '%s\n' "$merged" > "$target"
            log_info "$ide_name: merged → $target (backup: $(basename "$backup"))"
        else
            log_warn "$ide_name: merge failed — keeping original. Error: $merged"
            rm -f "$backup"
        fi
    done
fi

fi  # end Step 7

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
echo ""
echo "  Workspace-scoped Claude config (zamp-workspace/): NOT auto-deployed."
echo "    To link into a workspace dir, cd into it and run:"
echo "      bash $DOTFILES/zamp-workspace/link-here.sh"
echo "    (Or pass an explicit path: link-here.sh /path/to/workspace)"
