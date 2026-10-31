load helper
C="modules/claude"
setup() {
  setup_home
  for f in log os link module profile claude; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin" "$HOME/fake"
  : >"$HOME/fake/plugins"
  : >"$HOME/fake/calls"
  cat >"$HOME/bin/claude" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$HOME/fake/calls"
case "$1 $2 $3" in
  "plugin list --json")
    while IFS= read -r id; do printf '{"id":"%s","enabled":true,"scope":"user"}\n' "$id"; done <"$HOME/fake/plugins" | jq -s . ;;
  "plugin marketplace list")
    [ -e "$HOME/fake/marketplace" ] && echo '[{"name":"claude-plugins-official"}]' || echo '[]' ;;
  "plugin marketplace add") touch "$HOME/fake/marketplace" ;;
  "plugin install "*)
    echo "$3" >>"$HOME/fake/plugins"
    s="$HOME/.claude/settings.json"; mkdir -p "$HOME/.claude"; [ -f "$s" ] || echo '{}' >"$s"
    jq --arg id "$3" '.enabledPlugins[$id]=true' "$s" >"$s.t" && mv "$s.t" "$s" ;;
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
    "resources to learn more" "small reversible steps inside an agreed plan need no new plan"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "diagrams in chat are plain text, Mermaid only where it renders" {
  grep -qF "In chat, draw diagrams as plain text" "$DOTFILES_DIR/$C/home/.claude/rules/anand.md"
}

@test "no company data in the public module" {
  run grep -rniE 'z[a]mp|p[a]ntheon|@[a-z0-9-]+\.(ai|com)' "$DOTFILES_DIR/$C"
  [ "$status" -eq 1 ]
}

@test "no company names anywhere in the public repo" {
  cd "$DOTFILES_DIR"
  run grep -rniE 'z[a]mp|p[a]ntheon' docs modules lib tests profiles scripts README.md
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
  run jq -e '.permissions.defaultMode=="bypassPermissions" and .attribution=={"commit":"","pr":"","sessionUrl":false} and .cleanupPeriodDays==365
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
  jq -e '.model=="opus" and .effortLevel=="xhigh" and .attribution=={"commit":"","pr":"","sessionUrl":false} and .cleanupPeriodDays==365' "$HOME/.claude/settings.json"
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
    'Bash(git push * main *)' 'Bash(git push *:main)' 'Bash(git push *:main *)' \
    'Bash(git push * master *)' 'Bash(git push *:master)' 'Bash(git push *:master *)' \
    'Bash(git push * develop *)' 'Bash(git push *:develop)' 'Bash(git push *:develop *)' \
    'Bash(git push * release* *)' 'Bash(git push *:release*)' 'Bash(git push *:release* *)' \
    'Bash(git push --force *)' 'Bash(git push * --force)' 'Bash(git push * --force *)' \
    'Bash(git push -f *)' 'Bash(git push * -f)' 'Bash(git push * -f *)' \
    'Bash(git push --delete *)' 'Bash(git push * --delete *)' \
    'Bash(git reset --hard*)' 'Bash(git clean *)' 'Bash(git branch -D *)' \
    'Bash(docker system prune*)' 'Bash(docker volume rm *)' \
    'mcp__*send*' 'mcp__*create*' 'mcp__*update*' 'mcp__*delete*' 'mcp__*merge*'; do
    jq -e --arg r "$r" '.permissions.ask | index($r)' "$OWNED" >/dev/null || { echo "missing ask: $r"; return 1; }
  done
  run jq -e '.permissions.ask | map(select(test("force\\*|gh pr create|--force-with-lease"))) | length == 0' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "owned settings: connector ask globs match writes and never reads" {
  globs=()
  while IFS= read -r g; do globs+=("$g"); done < <(jq -r '.permissions.ask[] | select(startswith("mcp__"))' "$OWNED")
  [ "${#globs[@]}" -gt 0 ]
  matches() {
    local g
    for g in "${globs[@]}"; do
      # shellcheck disable=SC2254
      case "$1" in $g) return 0 ;; esac
    done
    return 1
  }
  local reads=(
    mcp__claude_ai_Slack__slack_read_channel mcp__claude_ai_Slack__slack_search_public
    mcp__claude_ai_Linear__list_issues mcp__claude_ai_Linear__get_issue
    mcp__claude_ai_Notion__notion-fetch mcp__claude_ai_Notion__notion-search
    mcp__claude_ai_Vercel__get_deployment mcp__claude_ai_Vercel__list_projects
    mcp__claude_ai_Sentry__search_issues mcp__claude_ai_Google_Drive__read_file_content
    mcp__claude_ai_Gmail__get_thread mcp__claude_ai_Google_Calendar__list_events
    mcp__claude_ai_Vercel__get_runtime_logs mcp__claude_ai_Slack__slack_read_user_profile
    mcp__claude_ai_Vercel__list_deployments mcp__claude_ai_Vercel__get_flag_settings
    mcp__claude_ai_Gmail__list_labels mcp__claude_ai_Linear__list_issue_labels
    mcp__claude_ai_Linear__list_comments mcp__claude_ai_Notion__notion-get-comments
    mcp__claude_ai_Notion__notion-list-shared-pages mcp__claude_ai_Notion__notion-get-suggested-edit
    mcp__claude_ai_Vercel__get_shared_env_var mcp__claude_ai_Vercel__get_toolbar_thread
  )
  local writes=(
    mcp__claude_ai_Slack__slack_send_message mcp__claude_ai_Slack__slack_schedule_message
    mcp__claude_ai_Linear__save_comment mcp__claude_ai_Linear__save_issue
    mcp__claude_ai_Notion__notion-create-comment mcp__claude_ai_Notion__notion-update-page
    mcp__claude_ai_Vercel__request_promote mcp__claude_ai_Vercel__request_rollback
    mcp__claude_ai_Vercel__create_deployment mcp__claude_ai_Vercel__add_project_domain
    mcp__claude_ai_Google_Docs__update_doc mcp__claude_ai_Gmail__create_draft
    mcp__claude_ai_Google_Calendar__create_event mcp__claude_ai_Sentry__update_issue
    mcp__claude_ai_Vercel__run_session_command mcp__claude_ai_Drive__share_file
    mcp__claude_ai_Linear__delete_comment mcp__claude_ai_Gmail__label_message
    mcp__claude_ai_Notion__notion-set-comment-reaction mcp__claude_ai_Vercel__edit_project_env
  )
  local t
  for t in "${reads[@]}"; do ! matches "$t" || { echo "read matches an ask glob: $t"; return 1; }; done
  for t in "${writes[@]}"; do matches "$t" || { echo "write matches no ask glob: $t"; return 1; }; done
}

@test "owned settings deny secret files and sops decrypt" {
  for r in 'Read(~/.secrets/**)' 'Edit(~/.secrets/**)' 'Read(**/.env)' 'Edit(**/.env)' 'Read(**/.env.*)' 'Edit(**/.env.*)' \
    'Read(~/.ssh/id_*)' 'Edit(~/.ssh/id_*)' 'Read(~/.aws/sso/cache/**)' 'Edit(~/.aws/sso/cache/**)' \
    'Edit(~/.claude/settings.json)' 'Bash(sops -d *)' 'Bash(sops decrypt *)' 'Bash(sops --decrypt *)'; do
    jq -e --arg r "$r" '.permissions.deny | index($r)' "$OWNED" >/dev/null || { echo "missing deny: $r"; return 1; }
  done
  run jq -e '.permissions.deny | length == 14' "$OWNED"
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
  grep -qF 'INFERRED needs its own yes' "$f"
  grep -qF 'promoted, then deleted' "$f"
  grep -qF 'go to `rules/anand.md`, not project memory' "$f"
  grep -qF 'DECISIONS.md' "$DOTFILES_DIR/$C/RESOLVER.md"
}

@test "building rules carry the test habits" {
  f="$DOTFILES_DIR/$C/home/.claude/rules/building.md"
  grep -qF 'watch it fail' "$f"
  grep -qF 'only the tests for what changed' "$f"
  grep -qF 'One heavy run at a time (full suite, build, image build); pytest at most -n 4; the full suite runs at phase close.' "$f"
}

@test "resolver names the owner of guard rails, plugins and statusline" {
  grep -qF '| Guard rails (ask and deny rules), plugins, statusline | `settings.owned.json` |' "$DOTFILES_DIR/$C/RESOLVER.md"
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

@test "merge owns only its own plugin configs" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{"pluginConfigs":{"other@m":{"options":{"x":1}},"cc-plugin-agents-md@builtin":{"options":{"instructionFiles":"claude-md"}}}}' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  jq -e '.pluginConfigs["other@m"]=={"options":{"x":1}}
    and .pluginConfigs["cc-plugin-agents-md@builtin"].options.instructionFiles=="claude-md-and-agents-md"' "$live"
  run claude_settings_drift "$OWNED" "$live"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "invalid live file is backed up and replaced" {
  live="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  echo '{oops' >"$live"
  claude_settings_merge "$OWNED" "$live" >/dev/null
  ls "$live".invalid.* >/dev/null
  grep -qF '{oops' "$live".invalid.*
  jq -e '.attribution=={"commit":"","pr":"","sessionUrl":false}' "$live"
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
  jq -r '.enabledPlugins | keys[]' "$OWNED" >"$HOME/fake/plugins"
  jq '.model="sonnet"' "$live" >"$live.t" && mv "$live.t" "$live"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  jq '.cleanupPeriodDays=1' "$live" >"$live.t" && mv "$live.t" "$live"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *cleanupPeriodDays* ]]
}

frag_tree() {
  export DOTFILES_MODULES="$HOME/mods" DOTFILES_PROFILES="$HOME/profiles" DOTFILES_PROFILE=p
  O="$HOME/personal/dotfiles-work"
  mkdir -p "$DOTFILES_MODULES/a" "$DOTFILES_MODULES/b" "$DOTFILES_MODULES/c" "$DOTFILES_PROFILES" "$O/modules/x"
  printf 'modules = ["a", "b"]\noverlay = true\n' >"$DOTFILES_PROFILES/p.toml"
  printf 'modules = ["a", "b"]\n' >"$DOTFILES_PROFILES/q.toml"
  echo '{"permissions":{"ask":["Bash(deploy *)","Bash(gh pr merge *)"]},"env":{"A":"1"}}' >"$DOTFILES_MODULES/a/claude-settings.json"
  echo '{"permissions":{"ask":["Bash(deploy *)"],"deny":["Read(~/.x/**)"]},"env":{"B":"2"}}' >"$DOTFILES_MODULES/b/claude-settings.json"
  echo '{"permissions":{"ask":["Bash(not-in-profile)"]}}' >"$DOTFILES_MODULES/c/claude-settings.json"
  echo '{"permissions":{"ask":["Bash(prod *)"]}}' >"$O/modules/x/claude-settings.json"
}

@test "expected: ask and deny concatenate without duplicates in order, other keys deep-merge" {
  echo '{"permissions":{"deny":["d1"],"ask":["a1","a2"],"defaultMode":"m"},"env":{"K":"0"},"x":1}' >"$HOME/o.json"
  echo '{"permissions":{"ask":["a2","a3"],"deny":["d2","d1"]},"env":{"L":"1"},"x":2}' >"$HOME/f1.json"
  echo '{"permissions":{"ask":["a4","a3"]}}' >"$HOME/f2.json"
  run claude_settings_expected "$HOME/o.json" "$HOME/f1.json" "$HOME/f2.json"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.permissions' <<<"$output")" = '{"deny":["d1","d2"],"ask":["a1","a2","a3","a4"],"defaultMode":"m"}' ]
  jq -e '.env=={"K":"0","L":"1"} and .x==2' <<<"$output"
}

@test "expected without fragments is the owned file" {
  run claude_settings_expected "$OWNED"
  [ "$status" -eq 0 ]
  [ "$(jq -cS . <<<"$output")" = "$(jq -cS . "$OWNED")" ]
}

@test "install lands public and overlay fragment rules in live settings; a second install keeps them" {
  frag_tree
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  live="$HOME/.claude/settings.json"
  jq -e '.permissions.ask | index("Bash(deploy *)") and index("Bash(prod *)") and index("Bash(gh pr merge *)")' "$live"
  jq -e '.permissions.deny | index("Read(~/.x/**)")' "$live"
  jq -e '.env.A=="1" and .env.B=="2"' "$live"
  [ "$(jq '[.permissions.ask[] | select(. == "Bash(deploy *)")] | length' "$live")" -eq 1 ]
  [ "$(jq '[.permissions.ask[] | select(. == "Bash(gh pr merge *)")] | length' "$live")" -eq 1 ]
  ! jq -e '.permissions.ask | index("Bash(not-in-profile)")' "$live" >/dev/null
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "${lines[${#lines[@]}-1]}" = "skip settings" ]
  jq -e '.permissions.ask | index("Bash(deploy *)")' "$live"
}

@test "overlay fragments apply only when the profile uses the overlay" {
  frag_tree
  DOTFILES_PROFILE=q run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  jq -e '.permissions.ask | index("Bash(deploy *)")' "$HOME/.claude/settings.json"
  ! jq -e '.permissions.ask | index("Bash(prod *)")' "$HOME/.claude/settings.json" >/dev/null
}

@test "doctor reports drift when a fragment rule is removed from the live file" {
  frag_tree
  bash "$DOTFILES_DIR/$C/install.sh" >/dev/null
  jq -r '.enabledPlugins | keys[]' "$OWNED" >"$HOME/fake/plugins"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -eq 0 ]; [ -z "$output" ]
  live="$HOME/.claude/settings.json"
  jq '.permissions.ask -= ["Bash(prod *)"]' "$live" >"$live.t" && mv "$live.t" "$live"
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]; [[ "$output" == *permissions* ]]
}

@test "install merges settings and dry run leaves them alone" {
  DRY_RUN=1 run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/settings.json" ]
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "${lines[${#lines[@]}-1]}" = "merged settings" ]
  jq -e '.attribution=={"commit":"","pr":"","sessionUrl":false}' "$HOME/.claude/settings.json"
}

plugins() { jq -r '.enabledPlugins | keys[]' "$OWNED"; }

@test "owned file enables the agreed plugins and sets the review model" {
  run jq -e '.enabledPlugins["superpowers@claude-plugins-official"]==true
    and .enabledPlugins["security-guidance@claude-plugins-official"]==true
    and .enabledPlugins["pyright-lsp@claude-plugins-official"]==true
    and .enabledPlugins["typescript-lsp@claude-plugins-official"]==true
    and .enabledPlugins["learning-output-style@claude-plugins-official"]==false
    and (.enabledPlugins|has("code-review@claude-plugins-official")|not)
    and (.enabledPlugins|has("code-simplifier@claude-plugins-official")|not)
    and .env.SECURITY_REVIEW_MODEL=="claude-sonnet-5-5"' "$OWNED"
  [ "$status" -eq 0 ]
}

@test "brewfile carries jq and the language servers" {
  for t in jq pyright typescript-language-server; do grep -q "^brew \"$t\"" "$DOTFILES_DIR/$C/Brewfile"; done
}

@test "installs every listed plugin once, the disabled one included" {
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  while IFS= read -r id; do
    [ "$(grep -cxF "plugin install $id --scope user" "$HOME/fake/calls")" -eq 1 ] || { echo "not once: $id"; return 1; }
  done < <(plugins)
  grep -qxF "plugin install learning-output-style@claude-plugins-official --scope user" "$HOME/fake/calls"
  grep -qxF "plugin marketplace add anthropics/claude-plugins-official" "$HOME/fake/calls"
}

@test "a plugin installed but owned as off stays off in settings" {
  run bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  jq -e '.enabledPlugins["learning-output-style@claude-plugins-official"]==false' "$HOME/.claude/settings.json"
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
  [[ "$output" == *"claude mcp add"* ]]
  run grep -qE "install|uninstall|marketplace add|mcp add" "$HOME/fake/calls"
  [ "$status" -eq 1 ]
}

@test "no claude CLI and a failing installer prints the commands" {
  rm "$HOME/bin/claude"; mkdir -p "$HOME/fakebin"
  printf '#!/usr/bin/env bash\nexit 22\n' >"$HOME/fakebin/curl"; chmod +x "$HOME/fakebin/curl"
  run env PATH="$HOME/fakebin:$(dirname "$(command -v jq)"):/usr/bin:/bin" bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed: curl -fsSL https://claude.ai/install.sh | bash"* ]]
  [[ "$output" == *"run: claude plugin install superpowers@claude-plugins-official --scope user"* ]]
  [[ "$output" == *"run: claude mcp add --scope user --transport http context7"* ]]
  jq -e '.attribution=={"commit":"","pr":"","sessionUrl":false}' "$HOME/.claude/settings.json"
}

no_claude() {
  mkdir -p "$HOME/stash" "$HOME/fakebin"
  mv "$HOME/bin/claude" "$HOME/stash/claude"
  cat >"$HOME/fakebin/curl" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$HOME/fake/curl"
cat <<'SCRIPT'
echo ran >>"$HOME/fake/installer"
mkdir -p "$HOME/.local/bin"
cp "$HOME/stash/claude" "$HOME/.local/bin/claude"
SCRIPT
FAKE
  chmod +x "$HOME/fakebin/curl"
  NOCLAUDE_PATH="$HOME/fakebin:$(dirname "$(command -v jq)"):/usr/bin:/bin"
}

@test "a missing claude is installed once with the official installer, then plugins use it" {
  no_claude
  run env PATH="$NOCLAUDE_PATH" bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [ "$(grep -c ran "$HOME/fake/installer")" -eq 1 ]
  grep -qxF -- "-fsSL https://claude.ai/install.sh" "$HOME/fake/curl"
  [ -x "$HOME/.local/bin/claude" ]
  grep -qxF "plugin install superpowers@claude-plugins-official --scope user" "$HOME/fake/calls"
  [[ "$output" != *"run: claude"* ]]
}

@test "claude already in ~/.local/bin or on PATH does not run the installer" {
  no_claude
  mkdir -p "$HOME/.local/bin"; cp "$HOME/stash/claude" "$HOME/.local/bin/claude"
  run env PATH="$NOCLAUDE_PATH" bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/fake/installer" ]
  grep -qxF "plugin install superpowers@claude-plugins-official --scope user" "$HOME/fake/calls"
  bash "$DOTFILES_DIR/$C/install.sh" >/dev/null
  [ ! -e "$HOME/fake/installer" ]
}

@test "dry run prints the installer and does not run it" {
  no_claude
  DRY_RUN=1 run env PATH="$NOCLAUDE_PATH" bash "$DOTFILES_DIR/$C/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"curl -fsSL https://claude.ai/install.sh | bash"* ]]
  [ ! -e "$HOME/fake/installer" ]; [ ! -e "$HOME/fake/curl" ]
  [ ! -e "$HOME/.local/bin/claude" ]
}

@test "doctor names an enabled plugin that is not installed" {
  claude_settings_merge "$OWNED" "$HOME/.claude/settings.json" >/dev/null
  run bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugin not installed: superpowers@claude-plugins-official"* ]]
}

@test "doctor fails when the claude CLI is missing" {
  claude_settings_merge "$OWNED" "$HOME/.claude/settings.json" >/dev/null
  rm "$HOME/bin/claude"
  run env PATH="$(dirname "$(command -v jq)"):/usr/bin:/bin" bash "$DOTFILES_DIR/$C/doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"claude CLI missing: plugins not checked"* ]]
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

@test "machine rules: tools through the dotfiles, runtimes through mise, packages through uv" {
  f="$DOTFILES_DIR/$C/home/.claude/rules/machine.md"
  for p in "never a one-off \`brew install\`" "Runtimes (node, python, go) come from mise" "never bare \`pip install\`" "dots doctor"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "writing rules forbid AI attribution anywhere" {
  grep -qF "No AI attribution anywhere" "$DOTFILES_DIR/$C/home/.claude/rules/writing.md"
}

@test "dictated formats are returned exactly" {
  grep -qF "When I dictate a format or bullets, return exactly that shape" "$DOTFILES_DIR/$C/home/.claude/rules/anand.md"
}

@test "machine rules say how to use secrets" {
  grep -qF 'with-secrets' "$DOTFILES_DIR/$C/home/.claude/rules/machine.md"
}
