#!/usr/bin/env bash
# Merge owned settings, then install the enabled plugins and context7 through the claude CLI; prune links to removed hooks.
set -euo pipefail
for f in log claude; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
owned="$DOTFILES_DIR/modules/claude/settings.owned.json"
hooks_src="$DOTFILES_DIR/modules/claude/home/.claude/hooks"
hooks_dst="$HOME/.claude/hooks"
marketplace="claude-plugins-official"
context7_url="https://mcp.context7.com/mcp"

if [ "${DRY_RUN:-0}" = 1 ]; then
  log_dry "merge owned settings into $HOME/.claude/settings.json"
  log_dry "prune stale links in $hooks_dst"
else
  if [ -d "$hooks_dst" ]; then
    for link in "$hooks_dst"/*; do
      if [ -L "$link" ] && [[ "$(readlink "$link")" == "$hooks_src"/* ]]; then
        rm "$link"
        echo "prune $link"
      fi
    done
    rmdir "$hooks_dst" 2>/dev/null || true
  fi
  claude_settings_merge "$owned" "$HOME/.claude/settings.json"
fi

have_cli=1
command -v claude >/dev/null 2>&1 || have_cli=0

# act DESCRIPTION CMD...: run the command, or print it when dry or there is no claude CLI.
act() {
  local desc="$1"
  shift
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "$*"
  elif [ "$have_cli" = 0 ]; then
    echo "run: $*"
  elif "$@" >/dev/null 2>&1; then
    echo "$desc"
  else
    log_warn "failed: $*"
  fi
}

installed=""
marketplaces=""
has_context7=0
if [ "$have_cli" = 1 ]; then
  installed="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"
  marketplaces="$(claude plugin marketplace list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)"
  claude mcp get context7 >/dev/null 2>&1 && has_context7=1
fi

if ! printf '%s\n' "$marketplaces" | grep -qx "$marketplace"; then
  act "added marketplace $marketplace" claude plugin marketplace add "anthropics/$marketplace"
fi
while IFS= read -r id; do
  printf '%s\n' "$installed" | grep -qxF "$id" || act "installed plugin $id" claude plugin install "$id" --scope user
done < <(jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$owned")
for dup in code-review code-simplifier; do
  if printf '%s\n' "$installed" | grep -qxF "$dup@$marketplace"; then
    act "removed plugin $dup@$marketplace" claude plugin uninstall "$dup@$marketplace"
  fi
done
if [ "$has_context7" = 0 ]; then
  act "added context7" claude mcp add --scope user --transport http context7 "$context7_url"
fi
exit 0
