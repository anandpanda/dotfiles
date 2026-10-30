load helper
C="modules/claude"
setup() {
  setup_home
  for f in log os link module profile claude; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin" "$HOME/fake"
  : >"$HOME/fake/plugins"
  cat >"$HOME/bin/claude" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$HOME/fake/calls"
case "$1 $2 $3" in
  "plugin list --json")
    while IFS= read -r id; do printf '{"id":"%s","enabled":true,"scope":"user"}\n' "$id"; done <"$HOME/fake/plugins" | jq -s . ;;
  "plugin marketplace list")
    [ -e "$HOME/fake/marketplace" ] && echo '[{"name":"claude-plugins-official"}]' || echo '[]' ;;
  "plugin marketplace add") touch "$HOME/fake/marketplace" ;;
  "plugin install "*) echo "$3" >>"$HOME/fake/plugins" ;;
  "plugin uninstall "*) grep -vxF "$3" "$HOME/fake/plugins" >"$HOME/fake/p.t" || true; mv "$HOME/fake/p.t" "$HOME/fake/plugins" ;;
  "mcp get context7") [ -e "$HOME/fake/context7" ] || exit 1 ;;
  "mcp add --scope") touch "$HOME/fake/context7" ;;
esac
FAKE
  chmod +x "$HOME/bin/claude"
  export PATH="$HOME/bin:$PATH"
}
teardown() { teardown_home; }

@test "claude module links CLAUDE.md and rules" {
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md" ]
  for r in anand writing evidence building; do
    [ "$(readlink "$HOME/.claude/rules/$r.md")" = "$DOTFILES_DIR/$C/home/.claude/rules/$r.md" ]
  done
}

@test "always-loaded instructions stay under 200 lines" {
  n=$(cat "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md" "$DOTFILES_DIR/$C"/home/.claude/rules/*.md | wc -l)
  [ "$n" -lt 200 ]
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

@test "owned settings ask before outward and destructive actions" {
  for r in 'Bash(gh pr merge *)' 'Bash(gh pr comment *)' 'Bash(gh pr review *)' 'Bash(gh workflow run *)' \
    'Bash(gh run rerun *)' 'Bash(gh run cancel *)' \
    'Bash(gh api *-X POST*)' 'Bash(gh api *-X PATCH*)' 'Bash(gh api *-X PUT*)' 'Bash(gh api *-X DELETE*)' \
    'Bash(gh api *--method POST*)' 'Bash(gh api *--method PATCH*)' 'Bash(gh api *--method PUT*)' 'Bash(gh api *--method DELETE*)' \
    'Bash(gh api *-f *)' 'Bash(gh api *-F *)' 'Bash(gh api *--field *)' 'Bash(gh api *--raw-field *)' \
    'Bash(git push * main)' 'Bash(git push * master)' 'Bash(git push * develop)' 'Bash(git push * release*)' \
    'Bash(git push --force *)' 'Bash(git push * --force)' 'Bash(git push * --force *)' \
    'Bash(git push -f *)' 'Bash(git push * -f)' 'Bash(git push * -f *)' \
    'Bash(git push --delete *)' 'Bash(git push * --delete *)' \
    'Bash(git reset --hard*)' 'Bash(git clean *)' 'Bash(git branch -D *)' \
    'Bash(docker system prune*)' 'Bash(docker volume rm *)' \
    'mcp__claude_ai_Slack__slack_send_message' 'mcp__claude_ai_Slack__slack_schedule_message' \
    'mcp__claude_ai_Linear__save_comment' 'mcp__claude_ai_Notion__notion-create-comment' \
    'mcp__*github*__*merge*' 'mcp__*github*__*comment*'; do
    jq -e --arg r "$r" '.permissions.ask | index($r)' "$OWNED" >/dev/null || { echo "missing ask: $r"; return 1; }
  done
  run jq -e '.permissions.ask | map(select(test("force\\*|gh pr create|--force-with-lease"))) | length == 0' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "owned settings deny secret files and sops decrypt" {
  for r in 'Read(~/.secrets/**)' 'Edit(~/.secrets/**)' 'Read(**/.env)' 'Read(**/.env.*)' 'Read(~/.ssh/id_*)' \
    'Read(~/.aws/sso/cache/**)' 'Edit(~/.claude/settings.json)' 'Bash(sops -d *)' 'Bash(sops decrypt *)'; do
    jq -e --arg r "$r" '.permissions.deny | index($r)' "$OWNED" >/dev/null || { echo "missing deny: $r"; return 1; }
  done
  run jq -e '.permissions.deny | length == 9' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "no allow rules are owned" {
  run jq -e '.permissions | has("allow") | not' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "no hooks key is owned" {
  run jq -e 'has("hooks") | not' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "the hooks directory is gone" {
  [ ! -e "$DOTFILES_DIR/$C/home/.claude/hooks" ]
  [ ! -e "$DOTFILES_DIR/tests/claude-hooks.bats" ]
}

@test "rules carry the decisions ledger" {
  f="$DOTFILES_DIR/$C/home/.claude/rules/building.md"
  grep -qF 'DECISIONS.md' "$f"
  grep -qF 'MEMORY.md' "$f"
  grep -qF '| date | decision | source | status |' "$f"
  grep -qF 'INFERRED' "$f"
  grep -qF 'DECISIONS.md' "$DOTFILES_DIR/$C/RESOLVER.md"
}

@test "building rules carry the test habits" {
  f="$DOTFILES_DIR/$C/home/.claude/rules/building.md"
  grep -qF 'watch it fail' "$f"
  grep -qF 'only the tests for what changed' "$f"
}

@test "install prunes stale links to removed hooks" {
  mkdir -p "$HOME/.claude/hooks"
  ln -s "$DOTFILES_DIR/$C/home/.claude/hooks/secrets-guard.sh" "$HOME/.claude/hooks/secrets-guard.sh"
  echo mine >"$HOME/.claude/hooks/own.sh"
  DRY_RUN=1 run bash "$DOTFILES_DIR/$C/install.sh"
  [ -L "$HOME/.claude/hooks/secrets-guard.sh" ]
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ ! -L "$HOME/.claude/hooks/secrets-guard.sh" ]
  [ -f "$HOME/.claude/hooks/own.sh" ]
}

@test "install removes the emptied hooks directory" {
  mkdir -p "$HOME/.claude/hooks"
  ln -s "$DOTFILES_DIR/$C/home/.claude/hooks/lib.sh" "$HOME/.claude/hooks/lib.sh"
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ ! -e "$HOME/.claude/hooks" ]
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
  jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$OWNED" >"$HOME/fake/plugins"
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
  [ "${lines[0]}" = "merged settings" ]
  jq -e '.attribution==false' "$HOME/.claude/settings.json"
}

enabled() { jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$OWNED"; }

@test "owned file enables the agreed plugins and sets the review model" {
  run jq -e '.enabledPlugins["superpowers@claude-plugins-official"]==true
    and .enabledPlugins["security-guidance@claude-plugins-official"]==true
    and .enabledPlugins["pyright-lsp@claude-plugins-official"]==true
    and .enabledPlugins["typescript-lsp@claude-plugins-official"]==true
    and .enabledPlugins["learning-output-style@claude-plugins-official"]==false
    and .enabledPlugins["code-review@claude-plugins-official"]==false
    and .enabledPlugins["code-simplifier@claude-plugins-official"]==false
    and .env.SECURITY_REVIEW_MODEL=="claude-sonnet-5-5"' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "brewfile carries jq and the language servers" {
  for t in jq pyright typescript-language-server; do grep -q "^brew \"$t\"" "$DOTFILES_DIR/$C/Brewfile"; done
}

@test "installs missing plugins once" {
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  while IFS= read -r id; do
    [ "$(grep -cxF "plugin install $id --scope user" "$HOME/fake/calls")" -eq 1 ] || { echo "not once: $id"; return 1; }
  done < <(enabled)
  grep -qxF "plugin marketplace add anthropics/claude-plugins-official" "$HOME/fake/calls"
  ! grep -q "install learning-output-style" "$HOME/fake/calls"
}

@test "second run calls nothing" {
  bash "$DOTFILES_DIR/$C/install.sh" >/dev/null
  : >"$HOME/fake/calls"
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  ! grep -qE "install|uninstall|marketplace add|mcp add" "$HOME/fake/calls"
}

@test "removes the duplicated review plugins" {
  printf '%s\n' code-review@claude-plugins-official code-simplifier@claude-plugins-official >"$HOME/fake/plugins"
  run bash "$DOTFILES_DIR/$C/install.sh"
  grep -qxF "plugin uninstall code-review@claude-plugins-official" "$HOME/fake/calls"
  grep -qxF "plugin uninstall code-simplifier@claude-plugins-official" "$HOME/fake/calls"
}

@test "adds context7 once" {
  bash "$DOTFILES_DIR/$C/install.sh" >/dev/null
  bash "$DOTFILES_DIR/$C/install.sh" >/dev/null
  [ "$(grep -c "^mcp add --scope user --transport http context7 https://mcp.context7.com/mcp$" "$HOME/fake/calls")" -eq 1 ]
}

@test "dry run changes nothing and prints the plan" {
  DRY_RUN=1 run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  ! grep -qE "install|uninstall|marketplace add|mcp add" "$HOME/fake/calls"
  [[ "$output" == *"claude mcp add"* ]]
}

@test "no claude CLI prints the commands" {
  rm "$HOME/bin/claude"
  run env PATH="$(dirname "$(command -v jq)"):/usr/bin:/bin" bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"run: claude plugin install superpowers@claude-plugins-official --scope user"* ]]
  [[ "$output" == *"run: claude mcp add --scope user --transport http context7"* ]]
  jq -e '.attribution==false' "$HOME/.claude/settings.json"
}

@test "doctor names an enabled plugin that is not installed" {
  claude_settings_merge "$OWNED" "$HOME/.claude/settings.json" >/dev/null
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugin not installed: superpowers@claude-plugins-official"* ]]
}

@test "doctor fails when jq is missing" {
  rm "$HOME/bin/claude"
  run env PATH="$HOME/nothing" /bin/bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"brew install jq"* ]]
}

STATUS="$BATS_TEST_DIRNAME/../modules/claude/home/.claude/statusline.sh"

mkrepo() {
  repo="$HOME/proj"
  git init -q -b main "$repo"
  git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}
sl() { printf '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":%s},"workspace":{"current_dir":"%s"}}' "$1" "$2" | bash "$STATUS"; }

@test "statusline shows model, context percent, repo and branch" {
  mkrepo
  run sl 23.7 "$repo"
  [ "$output" = "Opus · 23% · proj main" ]
}

@test "statusline marks a dirty tree with *" {
  mkrepo
  touch "$repo/new"
  run sl 5 "$repo"
  [ "$output" = "Opus · 5% · proj main*" ]
}

@test "statusline outside a repo shows only model and context" {
  mkdir "$HOME/plain"
  run sl 40 "$HOME/plain"
  [ "$output" = "Opus · 40%" ]
}

@test "statusline survives null context" {
  mkdir "$HOME/plain"
  run bash -c "printf '%s' '{\"model\":{\"display_name\":\"Opus\"},\"context_window\":{\"used_percentage\":null},\"workspace\":{\"current_dir\":\"$HOME/plain\"}}' | bash '$STATUS'"
  [ "$output" = "Opus · 0%" ]
}

@test "statusline makes one jq call" {
  mkrepo
  real="$(command -v jq)"
  printf '#!/bin/sh\necho x >>"%s/jqcalls"\nexec %s "$@"\n' "$HOME" "$real" >"$HOME/bin/jq"
  chmod +x "$HOME/bin/jq"
  run sl 10 "$repo"
  [ "$(wc -l <"$HOME/jqcalls" | tr -d ' ')" -eq 1 ]
}

@test "owned file wires the statusline" {
  run jq -e '.statusLine=={"type":"command","command":"$HOME/.claude/statusline.sh"}' "$OWNED"
  [ "$status" -eq 0 ]
  [ -x "$DOTFILES_DIR/$C/home/.claude/statusline.sh" ]
}
