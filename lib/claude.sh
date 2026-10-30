#!/usr/bin/env bash
# Claude Code owns ~/.claude/settings.json; the dotfiles own only the top-level keys in settings.owned.json.

CLAUDE_MERGE='def merge: .[0] + .[1] + {pluginConfigs: ((.[0].pluginConfigs // {}) + .[1].pluginConfigs)};'

# Rewrites each top-level key of OWNED into LIVE (replace; pluginConfigs one level deep). Prints "skip settings" or "merged settings".
claude_settings_merge() { # OWNED LIVE
  local owned="$1" live="$2" tmp
  mkdir -p "$(dirname "$live")"
  if [ -f "$live" ] && ! jq -e . "$live" >/dev/null 2>&1; then
    mv "$live" "$live.invalid.$(date +%s)"
  fi
  [ -f "$live" ] || echo '{}' >"$live"
  tmp="$(mktemp "$live.XXXXXX")"
  jq -s "$CLAUDE_MERGE merge" "$live" "$owned" >"$tmp" || {
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
  local owned="$1" live="$2" drifted
  drifted="$(jq -rs "$CLAUDE_MERGE merge as \$merged | .[0] as \$live | .[1] | keys[] | select(\$merged[.] != \$live[.])" "$live" "$owned" 2>/dev/null)" ||
    drifted="$(jq -r 'keys[]' "$owned")"
  [ -z "$drifted" ] && return 0
  echo "$drifted"
  return 1
}
