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

# Prints the owned settings with each fragment layered on: permissions.deny and .ask concatenate without duplicates, other keys deep-merge.
claude_settings_expected() { # OWNED [FRAGMENT...]
  local owned="$1"
  shift
  jq -s '
    def deep(a; b): if (a | type) == "object" and (b | type) == "object"
      then reduce (b | keys_unsorted[]) as $k (a; .[$k] = deep(.[$k]; b[$k])) else b end;
    def uniq: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
    def layer($f): . as $acc | deep($acc; $f)
      | reduce ("deny", "ask") as $k (.;
          if (($acc.permissions[$k] // []) + ($f.permissions[$k] // [])) == [] then .
          else .permissions[$k] = ((($acc.permissions[$k] // []) + ($f.permissions[$k] // [])) | uniq) end);
    reduce .[1:][] as $f (.[0]; layer($f))
  ' "$owned" "$@"
}

# Prints the claude-settings.json of every module the active profile applies, public first, then the overlay's.
claude_settings_fragments() {
  local dirs d
  dirs="$(profile_module_dirs "$(contexts_profile)")" || return 1
  while IFS= read -r d; do
    if [ -n "$d" ] && [ -f "$d/claude-settings.json" ]; then echo "$d/claude-settings.json"; fi
  done <<<"$dirs"
}
