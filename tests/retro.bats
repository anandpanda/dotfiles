load helper
R="modules/claude/home/.claude/skills/retro"
setup() {
  setup_home
  PAIRS="$DOTFILES_DIR/$R/pairs.sh"
  CHUNK="$DOTFILES_DIR/$R/chunk.sh"
  FIXTURE="$DOTFILES_DIR/tests/fixtures/retro/session.jsonl"
}
teardown() { teardown_home; }

entry() { "$PAIRS" "$FIXTURE" | jq -c --arg k "$1" 'select(.kind == $k) | {role, text, tools}'; }

@test "pairs keeps his prompts without IDE, reminder or image payload noise" {
  [ "$(entry prompt)" = $'{"role":"user","text":"fix the login bug","tools":null}\n{"role":"user","text":"[image] why is this red?","tools":null}' ]
}

@test "pairs merges one assistant turn into a single entry with a tool trail" {
  [ "$(entry reply | head -1)" = '{"role":"assistant","text":"Looking at the login code.","tools":"Bash(pytest tests/test_login.py) ×2, Edit(login.py)"}' ]
}

@test "pairs keeps rejections with his reason, and plain ones" {
  [ "$(entry rejection)" = $'{"role":"user","text":"Edit(login.py): dont touch login.py, fix the caller","tools":null}\n{"role":"user","text":"Bash(git checkout -b fix/login git push)","tools":null}' ]
}

@test "pairs marks a call stopped while running" {
  [ "$(entry stopped)" = '{"role":"user","text":"Bash(npm test)","tools":null}' ]
}

@test "pairs keeps messages he typed mid-turn and drops queued task notifications" {
  [ "$(entry queued)" = '{"role":"user","text":"and cut the branch from release","tools":null}' ]
}

@test "pairs keeps question answers, interrupts, slash commands and compaction" {
  [ "$(entry answer)" = '{"role":"user","text":"Which branch base? → release","tools":null}' ]
  [ "$(entry interrupt)" = '{"role":"user","text":"","tools":null}' ]
  [ "$(entry command)" = '{"role":"user","text":"/model claude-opus-5-5","tools":null}' ]
  [ "$(entry compacted)" = '{"role":"system","text":"","tools":null}' ]
}

@test "pairs drops tool output, thinking, meta, sidechain, summaries and metadata records" {
  run "$PAIRS" "$FIXTURE"
  [ "$status" -eq 0 ]
  for noise in "SHOULD NOT APPEAR" "secret thoughts" "Base directory" "ENV NOISE" "REMINDER NOISE" "task-notification" "local-command-stdout" "iVBORw0KGgo"; do
    case "$output" in *"$noise"*) echo "leaked: $noise"; return 1 ;; esac
  done
}

@test "pairs numbers entries in order with their first timestamp" {
  [ "$("$PAIRS" "$FIXTURE" | jq -r '"\(.i) \(.kind) \(.ts)"' | sed -n '1,3p')" = $'0 prompt 2026-11-18T12:00:01.000Z\n1 reply 2026-11-18T12:00:03.000Z\n2 rejection 2026-11-18T12:00:10.000Z' ]
  [ "$("$PAIRS" "$FIXTURE" | wc -l | tr -d ' ')" -eq 15 ]
}

@test "pairs stops and names an unknown content block type" {
  printf '%s\n' '{"type":"assistant","message":{"id":"m","role":"assistant","content":[{"type":"hologram"}]},"timestamp":"t"}' >"$HOME/s.jsonl"
  run "$PAIRS" "$HOME/s.jsonl"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown content block type: hologram"* ]]
}

@test "chunk cuts at his turns, carries the previous reply as context, and loses no line" {
  "$PAIRS" "$FIXTURE" >"$HOME/pairs.jsonl"
  run "$CHUNK" "$HOME/pairs.jsonl" "$HOME/chunks" 400
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -gt 2 ] || false
  [ "$(cat "$HOME"/chunks/chunk-*.jsonl | jq -c 'select(.context | not)')" = "$(jq -c . "$HOME/pairs.jsonl")" ]
  for c in "$HOME"/chunks/chunk-*.jsonl; do
    own="$(jq -c 'select(.context | not)' "$c")"
    [ "$(printf '%s\n' "$own" | head -1 | jq -r .role)" = user ] || [ "$c" = "$HOME/chunks/chunk-001.jsonl" ] || false
    [ "$(printf '%s\n' "$own" | wc -c | tr -d ' ')" -le 400 ] || [ "$(printf '%s\n' "$own" | jq -c 'select(.role == "user")' | wc -l | tr -d ' ')" -le 1 ] || false
  done
  [ "$(head -1 "$HOME/chunks/chunk-002.jsonl" | jq -c '{role, context}')" = '{"role":"assistant","context":true}' ]
  while IFS=$'\t' read -r path first last; do
    [ "$(jq -s -r 'map(select(.context | not)) | "\(first.i) \(last.i)"' "$path")" = "$first $last" ]
  done <<<"$output"
}

@test "chunk defaults to chunks one Read returns whole" {
  for n in $(seq 1 400); do
    jq -cn --argjson i "$((n * 2))" '{i: $i, role: "user", kind: "prompt", ts: "T", text: ("q" * 200)}'
    jq -cn --argjson i "$((n * 2 + 1))" '{i: $i, role: "assistant", kind: "reply", ts: "T", text: ("a" * 300)}'
  done >"$HOME/big.jsonl"
  run "$CHUNK" "$HOME/big.jsonl" "$HOME/big"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -ge 3 ] || false
  for c in "$HOME"/big/chunk-*.jsonl; do
    [ "$(jq -c 'select(.context | not)' "$c" | wc -c | tr -d ' ')" -le 80000 ] || false
  done
}

@test "the read workflow script parses as a workflow body" {
  command -v node >/dev/null || skip "node not installed"
  { echo '(async () => {'; sed 's/^export const meta/const meta/' "$DOTFILES_DIR/$R/read.js"; echo '})'; } >"$HOME/read.mjs"
  run node --check "$HOME/read.mjs"
  [ "$status" -eq 0 ]
}

@test "pairs skips a torn transcript line, keeps the rest and names the line" {
  {
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"first"},"timestamp":"T1"}'
    printf '%s\n' '{"type":"assistant","message":{"id":"m","role":"assist{"type":"user","message":{"role":"user","content":"glued"},"timestamp":"T2"}'
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"third"},"timestamp":"T3"}'
  } >"$HOME/torn.jsonl"
  run "$PAIRS" "$HOME/torn.jsonl"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r 'select(.kind == "prompt") | .text' | paste -sd, -)" = "first,third" ]
  [ "$(echo "$output" | jq -r 'select(.kind == "unreadable") | .text')" = "transcript line 2 could not be parsed" ]
}

@test "pairs reads a slash command whichever command tag comes first" {
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>insights</command-message>\n<command-name>/insights</command-name>"},"timestamp":"T1"}' >"$HOME/cmd.jsonl"
  [ "$("$PAIRS" "$HOME/cmd.jsonl" | jq -c '{kind, text}')" = '{"kind":"command","text":"/insights"}' ]
}

commit_at() { GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" git -C "$HOME/repo" -c user.name=t -c user.email=t@t commit -qam "$2"; }

@test "harness-then rebuilds the linked harness as it was at a time, deleted files included" {
  m="$HOME/repo/modules/x/home/.claude"
  mkdir -p "$m/rules" "$HOME/.claude/rules"
  git -C "$HOME/repo" init -q
  echo old >"$m/rules/a.md"; echo gone >"$m/rules/b.md"
  git -C "$HOME/repo" add -A; commit_at "2026-11-01T00:00:00Z" one
  echo new >"$m/rules/a.md"; git -C "$HOME/repo" rm -q "$m/rules/b.md"; echo later >"$m/rules/c.md"
  git -C "$HOME/repo" add -A; commit_at "2026-11-10T00:00:00Z" two
  ln -s "$m/rules/a.md" "$HOME/.claude/rules/a.md"
  ln -s "$m/rules/c.md" "$HOME/.claude/rules/c.md"
  echo local >"$HOME/.claude/CLAUDE.md"
  run "$DOTFILES_DIR/$R/harness-then.sh" "2026-11-05T12:00:00Z" "$HOME/then"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/then/.claude/rules/a.md")" = old ]
  [ "$(cat "$HOME/then/.claude/rules/b.md")" = gone ]
  [ ! -e "$HOME/then/.claude/rules/c.md" ] || false
  [[ "$output" == *"$HOME/repo at $(git -C "$HOME/repo" rev-parse --short HEAD~1)"* ]]
  [[ "$output" == *"not versioned: $HOME/.claude/CLAUDE.md"* ]]
}

@test "harness-now copies today's linked harness as real files" {
  mkdir -p "$HOME/src" "$HOME/.claude/rules" "$HOME/.claude/skills/s"
  echo rule >"$HOME/src/a.md"; echo skill >"$HOME/src/SKILL.md"
  ln -s "$HOME/src/a.md" "$HOME/.claude/rules/a.md"
  ln -s "$HOME/src/SKILL.md" "$HOME/.claude/skills/s/SKILL.md"
  echo local >"$HOME/.claude/CLAUDE.md"
  run "$DOTFILES_DIR/$R/harness-now.sh" "$HOME/now"
  [ "$status" -eq 0 ]
  [ -f "$HOME/now/.claude/rules/a.md" ] && [ ! -L "$HOME/now/.claude/rules/a.md" ] || false
  [ "$(cat "$HOME/now/.claude/skills/s/SKILL.md")" = skill ]
  [ "$(cat "$HOME/now/.claude/CLAUDE.md")" = local ]
}
