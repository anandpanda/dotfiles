#!/usr/bin/env bash
# Owned settings plus module fragments must match the live file; every listed plugin installed; jq and the claude CLI present.
set -euo pipefail
for f in log os profile module contexts claude; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
owned="$DOTFILES_DIR/modules/claude/settings.owned.json"
fail=0
if ! command -v jq >/dev/null 2>&1; then
  echo "jq missing: brew install jq"
  exit 1
fi
fragments="$(claude_settings_fragments)" || {
  echo "cannot discover settings fragments"
  exit 1
}
frags=()
while IFS= read -r f; do [ -z "$f" ] || frags+=("$f"); done <<<"$fragments"
expected="$(mktemp)"
trap 'rm -f "$expected"' EXIT
claude_settings_expected "$owned" ${frags[@]+"${frags[@]}"} >"$expected" || {
  echo "cannot combine settings fragments"
  exit 1
}
claude_settings_drift "$expected" "$HOME/.claude/settings.json" || fail=1
if command -v claude >/dev/null 2>&1; then
  installed="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"
  while IFS= read -r id; do
    printf '%s\n' "$installed" | grep -qxF "$id" || {
      echo "plugin not installed: $id"
      fail=1
    }
  done < <(jq -r '.enabledPlugins | keys[]' "$owned")
else
  echo "claude CLI missing: plugins not checked"
  fail=1
fi
exit "$fail"
