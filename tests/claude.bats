load helper
C="modules/claude"
setup() { setup_home; for f in log os link module profile claude; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "claude module links CLAUDE.md and rules" {
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md" ]
  for r in anand writing evidence building; do
    [ "$(readlink "$HOME/.claude/rules/$r.md")" = "$DOTFILES_DIR/$C/home/.claude/rules/$r.md" ]
  done
}

@test "CLAUDE.md stays short" {
  n=$(wc -l < "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"); [ "$n" -le 45 ]
}

@test "working agreement carries the agreed rules" {
  f="$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  for p in "literal question" "UNVERIFIED" "stands because" "not a go" "small reversible" \
    "No comments in code" "AI slop" "Do not overcorrect" "outrank plugin skills" \
    "senior principal engineer" "the tradeoff and why" "No paranoia" "Planning is mandatory" \
    "Never post a reply to a PR comment" "Assume I know nothing" "pick the type that fits" \
    "resources to learn more"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "no company data in the public module" {
  run grep -rniE 'work|backend|@[a-z0-9-]+\.(ai|com)' "$DOTFILES_DIR/$C"
  [ "$status" -eq 1 ]
}

@test "resolver names an existing owner file for every rule heading" {
  f="$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  n=$(grep -c '^## ' "$f"); [ "$n" -ge 6 ]
  while IFS= read -r h; do
    row=$(grep -F "| ${h#\#\# } |" "$DOTFILES_DIR/$C/RESOLVER.md") || { echo "no owner: $h"; return 1; }
    owners=$(printf '%s\n' "$row" | grep -oE '`[^`]+`' | tr -d '`')
    [ -n "$owners" ] || { echo "no owner file: $h"; return 1; }
    for o in $owners; do [ -f "$DOTFILES_DIR/$C/$o" ] || { echo "missing owner $o for $h"; return 1; }; done
  done < <(grep '^## ' "$f")
}

@test "claude is in personal and server profiles" {
  grep -qF '"claude"' "$DOTFILES_DIR/profiles/personal.toml"
  grep -qF '"claude"' "$DOTFILES_DIR/profiles/server.toml"
  unset DOTFILES_PROFILES
  run profile_modules personal
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx claude
  run profile_modules server
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx claude
}

@test "learning mode triggers have one home" {
  grep -qF '"teach", "with me", "guide me" or "together"' "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  run grep -nE '"teach"|"guide me"|"explain"' "$DOTFILES_DIR/$C/home/.claude/rules/anand.md"
  [ "$status" -eq 1 ]
}

OWNED="$BATS_TEST_DIRNAME/../modules/claude/settings.owned.json"

@test "owned file sets the verbatim values" {
  run jq -e '.permissions.defaultMode=="bypassPermissions" and .attribution==false and .cleanupPeriodDays==365
    and .pluginConfigs["cc-plugin-agents-md@builtin"].options.instructionFiles=="claude-md-and-agents-md"
    and (has("model")|not) and (has("effortLevel")|not) and (has("modelSettings")|not)' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "merge adds owned keys and keeps model and effort" {
  mkdir -p "$HOME/.claude"
  echo '{"model":"opus","effortLevel":"xhigh"}' >"$HOME/.claude/settings.json"
  run claude_settings_merge "$OWNED" "$HOME/.claude/settings.json"
  [ "$status" -eq 0 ]
  [ "$output" = "merged settings" ]
  jq -e '.model=="opus" and .effortLevel=="xhigh" and .attribution==false and .cleanupPeriodDays==365' "$HOME/.claude/settings.json"
}

@test "merge is idempotent" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{"model":"opus"}' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  cp "$live" "$HOME/before.json"
  run claude_settings_merge "$OWNED" "$live"
  [ "$output" = "skip settings" ]
  cmp "$live" "$HOME/before.json"
}

@test "merge restores a loosened deny" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{}' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  jq '.permissions.deny |= .[1:]' "$live" >"$live.t" && mv "$live.t" "$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  [ "$(jq -c .permissions.deny "$live")" = "$(jq -c .permissions.deny "$OWNED")" ]
}

@test "invalid live file is backed up and replaced" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{oops' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  ls "$live".invalid.* >/dev/null
  grep -qF '{oops' "$live".invalid.*
  jq -e '.attribution==false' "$live"
}

@test "missing live file is created" {
  live="$HOME/.claude/settings.json"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  jq -e '.cleanupPeriodDays==365' "$live"
}

@test "doctor reports drift on owned keys only" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{}' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  jq '.model="sonnet"' "$live" >"$live.t" && mv "$live.t" "$live"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  jq '.cleanupPeriodDays=1' "$live" >"$live.t" && mv "$live.t" "$live"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *cleanupPeriodDays* ]]
}

@test "install merges settings and dry run leaves them alone" {
  DRY_RUN=1 run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/settings.json" ]
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$output" = "merged settings" ]
  jq -e '.attribution==false' "$HOME/.claude/settings.json"
}
