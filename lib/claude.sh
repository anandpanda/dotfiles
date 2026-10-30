#!/usr/bin/env bash
# Claude Code owns ~/.claude/settings.json; the dotfiles own only the top-level keys in settings.owned.json.

# Rewrites each top-level key of OWNED into LIVE (replace, not deep merge). Prints "skip settings" or "merged settings".
claude_settings_merge() { # OWNED LIVE
  local owned="$1" live="$2" tmp
  mkdir -p "$(dirname "$live")"
  if [ -f "$live" ] && ! jq -e . "$live" >/dev/null 2>&1; then
    mv "$live" "$live.invalid.$(date +%s)"
  fi
  [ -f "$live" ] || echo '{}' >"$live"
  tmp="$(mktemp "$live.XXXXXX")"
  jq -s '.[0] + .[1]' "$live" "$owned" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  if [ "$(jq -cS . "$live")" = "$(jq -cS . "$tmp")" ]; then
    rm -f "$tmp"
    echo "skip settings"
  else
    mv "$tmp" "$live"
    echo "merged settings"
  fi
}

# Prints each owned key whose live value differs; exit 1 if any.
claude_settings_drift() { # OWNED LIVE
  local owned="$1" live="$2" key drift=0
  while IFS= read -r key; do
    if [ "$(jq -cS --arg k "$key" '.[$k]' "$owned")" != "$(jq -cS --arg k "$key" '.[$k]' "$live" 2>/dev/null)" ]; then
      echo "$key"
      drift=1
    fi
  done < <(jq -r 'keys[]' "$owned")
  return "$drift"
}
