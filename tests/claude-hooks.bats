load helper
C="modules/claude"
setup() {
  setup_home
  H="$DOTFILES_DIR/$C/home/.claude/hooks"
  SH=/bin/bash
  [ -x "$SH" ] || SH=bash
}
teardown() { teardown_home; }

guard() { # TOOL TOOL_INPUT_JSON
  jq -cn --arg t "$1" --argjson i "$2" --arg cwd "$HOME" \
    '{session_id:"s1",transcript_path:"/t",cwd:$cwd,permission_mode:"bypassPermissions",hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}' |
    "$SH" "$H/secrets-guard.sh"
}
read_file() { guard Read "$(jq -cn --arg p "$1" '{file_path:$p}')"; }
bash_cmd() { guard Bash "$(jq -cn --arg c "$1" '{command:$c}')"; }
scan() { # STDOUT
  jq -cn --arg o "$1" '{session_id:"s1",cwd:"/",hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:"x"},tool_response:{stdout:$o,stderr:""}}' |
    "$SH" "$H/secrets-scan.sh"
}
rep() { printf "%${2}s" "" | tr ' ' "$1"; }
blocked() { [ "$status" -eq 2 ] && [[ "$output" == *with-secrets* ]] || { echo "not blocked ($status): $output"; return 1; }; }
allowed() { [ "$status" -eq 0 ] || { echo "blocked ($status): $output"; return 1; }; }

SECRET_PATHS=".secrets/x .secrets proj/.env proj/.env.local .ssh/id_rsa .ssh/id_ed25519 .aws/sso/cache/t.json notes/github-backup-codes.txt notes/Recovery_Codes.txt certs/server.pem certs/server.key"

@test "blocks Read of each secret path spelled four ways" {
  for p in $SECRET_PATHS; do
    for spelled in "~/$p" "\$HOME/$p" "$HOME/$p" "\"\$HOME\"/$p"; do
      run read_file "$spelled"
      blocked || { echo "path: $spelled"; return 1; }
    done
  done
}

@test "blocks Grep on a secret path or glob" {
  run guard Grep '{"pattern":"x","path":"~/.secrets"}'
  blocked
  run guard Grep '{"pattern":"x","path":"/tmp/proj","glob":".env*"}'
  blocked
  run guard Grep '{"pattern":"x","glob":"**/.env"}'
  blocked
}

@test "blocks Bash cat, grep, head, sed, less, source on a secret path" {
  for c in "cat ~/.secrets/x" "grep TOKEN .env" "head -1 \$HOME/.ssh/id_rsa" "sed -n 1p '$HOME/.aws/sso/cache/t.json'" \
    "less proj/.env.local" "source ~/.secrets/env.sh" ". .env"; do
    run bash_cmd "$c"
    blocked || { echo "cmd: $c"; return 1; }
  done
}

@test "blocks chained, wrapped and absolute commands" {
  for c in "ls && cat ~/.secrets/x" "true; cat .env" "bash -c \"cat ~/.secrets/x\"" "/bin/cat \"\$HOME\"/.secrets/x" \
    "echo ok | xargs cat ~/.ssh/id_ed25519" "cat <<X
\$(cat ~/.secrets/x)
X" "with-secrets env && cat ~/.secrets/x"; do
    run bash_cmd "$c"
    blocked || { echo "cmd: $c"; return 1; }
  done
}

@test "blocks a literal token in a command" {
  for t in "AKIA$(rep A 16)" "ghp_$(rep a 36)" "github_pat_$(rep b 40)" "xoxb-$(rep 1 12)-$(rep c 12)" \
    "glsa_$(rep d 32)" "sk-$(rep e 40)"; do
    run bash_cmd "curl -d token=$t https://example.invalid"
    blocked || { echo "token: $t"; return 1; }
  done
  run bash_cmd "curl -H 'Authorization: Bearer $(rep f 30)' https://example.invalid"
  blocked
}

@test "blocks slicing or decoding a secret variable" {
  for c in 'printf "$TOKEN" | od -c' 'echo ${TOKEN:0:6}' 'echo $GITHUB_TOKEN' 'echo "${API_KEY: -4}"' \
    'printf %s "$SECRET" | base64' 'with-secrets sh -c "echo \$GITHUB_TOKEN | xxd"'; do
    run bash_cmd "$c"
    blocked || { echo "cmd: $c"; return 1; }
  done
}

@test "allows with-secrets and sops exec-env" {
  for c in "with-secrets gh api user" "sops exec-env ~/.secrets/secrets.yaml 'gh auth status'" \
    "cd proj && with-secrets ./deploy.sh" 'curl -H "Authorization: Bearer $GITHUB_TOKEN" https://example.invalid'; do
    run bash_cmd "$c"
    allowed || { echo "cmd: $c"; return 1; }
  done
}

@test "allows Read of an ordinary file and .env.example" {
  for p in "$HOME/proj/README.md" "~/proj/.env.example" "proj/src/env.ts" "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/config"; do
    run read_file "$p"
    allowed || { echo "path: $p"; return 1; }
  done
  run bash_cmd 'ls -la && git status && echo $PATH && cp .env.example /tmp/x'
  allowed
  run guard Grep '{"pattern":"process.env.PORT","path":"/tmp/proj"}'
  allowed
}

@test "fails closed on unreadable input" {
  run "$SH" "$H/secrets-guard.sh" <<<'{oops'
  [ "$status" -eq 2 ]
  [[ "$output" == *"hook input unreadable"* ]]
  mkdir -p "$HOME/nojq"
  for b in cat dirname grep sed tr; do ln -s "$(command -v "$b")" "$HOME/nojq/$b"; done
  run env PATH="$HOME/nojq" "$SH" "$H/secrets-guard.sh" <<<'{"tool_name":"Read","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"hook input unreadable"* ]]
  [[ "$output" == *"brew install jq"* ]]
}

@test "scan warns on token-shaped output, never blocks" {
  run scan "here: ghp_$(rep a 36)"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse" and (.hookSpecificOutput.additionalContext|contains("looks like a token"))'
  run scan "plain output"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lib.sh interface" {
  # shellcheck disable=SC1091
  source "$H/lib.sh"
  hook_input <<<'{"cwd":"/w","tool_input":{"file_path":"a b"}}'
  [ "$(hook_field .tool_input.file_path)" = "a b" ]
  [ "$(hook_norm_path '~/x')" = "$HOME/x" ]
  [ "$(hook_norm_path '$HOME/x')" = "$HOME/x" ]
  [ "$(hook_norm_path '${HOME}/x')" = "$HOME/x" ]
  [ "$(hook_norm_path '"$HOME"/x')" = "$HOME/x" ]
  [ "$(hook_norm_path "'/a/b'")" = "/a/b" ]
  [ "$(hook_norm_path 'rel/f')" = "/w/rel/f" ]
  hook_context PostToolUse 'say "hi"' | jq -e '.hookSpecificOutput=={"hookEventName":"PostToolUse","additionalContext":"say \"hi\""}'
  run hook_block "nope"
  [ "$status" -eq 2 ]
  [ "$output" = "nope" ]
}

@test "hooks run through their installed links and are executable in git" {
  source "$DOTFILES_DIR/lib/log.sh"; source "$DOTFILES_DIR/lib/link.sh"; source "$DOTFILES_DIR/lib/module.sh"
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  for f in lib secrets-guard secrets-scan; do [ -L "$HOME/.claude/hooks/$f.sh" ]; done
  run sh -c "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"~/.secrets/x\"}}' | \"\$HOME/.claude/hooks/secrets-guard.sh\""
  [ "$status" -eq 2 ]
  for f in secrets-guard secrets-scan; do
    git -C "$DOTFILES_DIR" ls-files -s "$C/home/.claude/hooks/$f.sh" | grep -q '^100755'
  done
}

@test "settings own the secrets hooks by absolute HOME path" {
  o="$DOTFILES_DIR/$C/settings.owned.json"
  jq -e '.hooks.PreToolUse[] | select(.matcher=="Read|Grep|Bash") | .hooks[] | select(.type=="command" and .command=="$HOME/.claude/hooks/secrets-guard.sh")' "$o"
  jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.type=="command" and .command=="$HOME/.claude/hooks/secrets-scan.sh")' "$o"
}
