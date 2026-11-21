load helper
C="modules/claude"
SKILLS="explain grill pr-description voice-draft review-change research find-past-session handoff retro scout"
USER_ONLY="review-change handoff retro scout"
setup() {
  setup_home
  S="$DOTFILES_DIR/$C/home/.claude/skills"
  A="$DOTFILES_DIR/$C/home/.claude/agents"
}
teardown() { teardown_home; }

front() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }
field() { front "$1" | sed -n "s/^$2: //p"; }

@test "every skill has name and description frontmatter on line 1" {
  for s in $SKILLS; do
    f="$S/$s/SKILL.md"
    [ "$(head -1 "$f")" = "---" ] || { echo "no frontmatter: $s"; return 1; }
    [ "$(field "$f" name)" = "$s" ] || { echo "bad name: $s"; return 1; }
    [ -n "$(field "$f" description)" ] || { echo "no description: $s"; return 1; }
  done
  [ "$(find "$S" -name SKILL.md | wc -l | tr -d ' ')" -eq 10 ]
}

@test "side-effect skills disable model invocation" {
  for s in $SKILLS; do
    v="$(field "$S/$s/SKILL.md" disable-model-invocation)"
    case " $USER_ONLY " in
      *" $s "*)
        [ "$v" = true ] || { echo "model can invoke: $s"; return 1; }
        [[ "$(field "$S/$s/SKILL.md" description)" == "/$s"* ]] || { echo "description not /usage: $s"; return 1; }
        ;;
      *) [ -z "$v" ] || { echo "user-only by mistake: $s"; return 1; } ;;
    esac
  done
}

@test "no skill shares a name with a team skill" {
  for t in pr-review grill-me; do
    [ ! -e "$S/$t" ]
    run grep -rlx "name: $t" "$S"
    [ "$status" -eq 1 ]
  done
}

@test "agents carry the agreed tools, model and effort" {
  [ "$(field "$A/reviewer.md" tools)" = "Read, Grep, Glob" ]
  [ "$(field "$A/reviewer.md" model)" = opus ]
  [ "$(field "$A/reviewer.md" effort)" = high ]
  [ "$(field "$A/researcher.md" tools)" = "Read, Grep, Glob, WebSearch, WebFetch, Write" ]
  [ "$(field "$A/researcher.md" model)" = sonnet ]
  [ "$(field "$A/researcher.md" effort)" = medium ]
  [ -z "$(field "$A/worker.md" tools)" ]
  [ "$(field "$A/worker.md" model)" = haiku ]
  [ "$(field "$A/worker.md" effort)" = low ]
  [ "$(field "$A/retro-reader.md" tools)" = Read ]
  [ "$(field "$A/retro-reader.md" model)" = sonnet ]
  [ "$(field "$A/retro-reader.md" effort)" = medium ]
  for a in reviewer researcher worker retro-reader; do
    [ "$(head -1 "$A/$a.md")" = "---" ]
    [ "$(field "$A/$a.md" name)" = "$a" ]
    [ -n "$(field "$A/$a.md" description)" ]
  done
}

@test "every agent body carries the subagent standing rules" {
  for a in reviewer researcher worker retro-reader; do
    for p in "Nothing fake" "Skip no check" "Stay on the task"; do
      grep -qF "$p" "$A/$a.md" || { echo "$a missing: $p"; return 1; }
    done
  done
  grep -qF "Return the path and the count" "$A/researcher.md"
  grep -qF "Return the path and the count" "$A/worker.md"
  grep -qF "You cannot write files. Put your findings in your final message" "$A/reviewer.md"
  grep -qF "Write your findings to the file" "$A/researcher.md"
  grep -qF "Write your findings to the file" "$A/worker.md"
  grep -qF "Return the moments as your structured output" "$A/retro-reader.md"
  grep -qF "Cite the \`i\` field" "$A/retro-reader.md"
  grep -qF "anti-cheat contract" "$A/worker.md"
}

@test "reviewer cannot edit" {
  run sh -c "sed -n 's/^tools: //p' '$A/reviewer.md' | grep -E 'Edit|Write|Bash|NotebookEdit'"
  [ "$status" -eq 1 ]
  grep -qF "the task and its claims, never the reasoning" "$A/reviewer.md"
  grep -qF "pass on a no-op" "$A/reviewer.md"
}

@test "pr-description forbids a testing section and requires a diagram" {
  f="$S/pr-description/SKILL.md"
  grep -qF "No testing section" "$f"
  grep -qF "mermaid" "$f"
  grep -qF "No merge-risk section" "$f"
  grep -qF "What did not change" "$f"
  grep -qF "No AI attribution" "$f"
  run grep -F "only on his go" "$f"
  [ "$status" -eq 1 ]
}

@test "voice-draft is model-invocable and posts only once he confirms the draft" {
  [ -z "$(field "$S/voice-draft/SKILL.md" disable-model-invocation)" ]
  grep -qF "Post only once he confirms the draft" "$S/voice-draft/SKILL.md"
  run grep -F "he posts it himself" "$S/voice-draft/SKILL.md"
  [ "$status" -eq 1 ] || false
}

@test "voice-draft asks with should we, one problem and one ask per review comment" {
  f="$S/voice-draft/SKILL.md"
  grep -qF '"should we X?"' "$f"
  grep -qF 'never "can we X?"' "$f"
  grep -qF "one problem and one ask" "$f"
}

@test "the review engine hands the reviewer a diff from the merge base" {
  R="$DOTFILES_DIR/$C/home/.claude/review"
  grep -qF '`diff.patch`' "$R/run.md"
  grep -qF "never a two-dot diff" "$R/run.md"
  grep -qF "git merge-base" "$S/review-change/SKILL.md"
}

@test "skills call bundled scripts through the skill dir and know their own session" {
  grep -qF '${CLAUDE_SKILL_DIR}/pairs.sh' "$S/retro/SKILL.md"
  grep -qF 'pairs.sh ${CLAUDE_SESSION_ID}' "$S/retro/SKILL.md"
  grep -qF '${CLAUDE_SKILL_DIR}/chunk.sh' "$S/retro/SKILL.md"
  grep -qF '${CLAUDE_SKILL_DIR}/harness-then.sh' "$S/retro/SKILL.md"
  grep -qF '${CLAUDE_SKILL_DIR}/ledger.md' "$S/retro/SKILL.md"
  grep -qF '${CLAUDE_SKILL_DIR}/read.js' "$S/retro/SKILL.md"
  grep -qF '${CLAUDE_SKILL_DIR}/search.sh --exclude "${CLAUDE_SESSION_ID}"' "$S/find-past-session/SKILL.md"
  run grep -rE '~/\.claude/skills/[a-z-]+/[a-z]+\.sh' "$S"
  [ "$status" -eq 1 ]
}

@test "grill and scout limit their writes" {
  grep -qF "the decisions ledger is the only write" "$S/grill/SKILL.md"
  grep -qF "scratchpad" "$S/scout/SKILL.md"
}

@test "review-change finds, refutes and drafts replies through voice-draft" {
  f="$S/review-change/SKILL.md"
  R="$DOTFILES_DIR/$C/home/.claude/review"
  grep -qF "refute.md" "$R/run.md"
  grep -qF "needs a line you read" "$R/lenses.md"
  for p in "Ledger" "voice-draft" "once he confirms the draft"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "review-change reviews his own work with the tests lens and the anti-cheat contract" {
  R="$DOTFILES_DIR/$C/home/.claude/review"
  grep -qF "mode \`own\`" "$S/review-change/SKILL.md"
  grep -qF "## 8. Tests (own mode only)" "$R/lenses.md"
  grep -qF "Anti-cheat contract" "$R/lenses.md"
  [ ! -e "$S/phase-close" ]
}

@test "explain and grill follow the agreed shape" {
  for p in "Map" "one step" "flow, sequence, state, architecture" "Resources" "Restate" "Artifact"; do
    grep -qF "$p" "$S/explain/SKILL.md" || { echo "explain missing: $p"; return 1; }
  done
  for p in "Number every question" "Recommended:" "Facts are yours to look up"; do
    grep -qF "$p" "$S/grill/SKILL.md" || { echo "grill missing: $p"; return 1; }
  done
}

@test "retro and scout are user-invoked only and never commit" {
  for s in retro scout; do
    f="$S/$s/SKILL.md"
    [ "$(field "$f" disable-model-invocation)" = true ]
    grep -qF "Edit nothing and commit nothing until Anand picks" "$f" || { echo "$s may apply"; return 1; }
    grep -qF "researcher" "$f" || { echo "$s has no researcher"; return 1; }
  done
  for p in "rule add" "permission rule" "skill or agent" "plugin or feature" "pairs.sh"; do
    grep -qF "$p" "$S/retro/SKILL.md" || { echo "retro missing: $p"; return 1; }
  done
  for p in "official" "marketplaces" "trending code" "discussion" "practitioners" "30 days" \
    "adopt / try / skip" "could not reach" "already installed"; do
    grep -qF "$p" "$S/scout/SKILL.md" || { echo "scout missing: $p"; return 1; }
  done
}

@test "skills stay short and use no em-dashes" {
  for s in $SKILLS; do
    [ "$(wc -l <"$S/$s/SKILL.md")" -le 70 ] || { echo "long: $s"; return 1; }
  done
  run grep -rl '—' "$S" "$A"
  [ "$status" -eq 1 ]
}

@test "resolver rows point at files that exist" {
  r="$DOTFILES_DIR/$C/RESOLVER.md"
  for s in pr-description review-change voice-draft explain retro scout; do
    grep -qF "home/.claude/skills/$s/SKILL.md" "$r" || { echo "no resolver row: $s"; return 1; }
  done
  grep -qF "home/.claude/agents/reviewer.md" "$r"
  grep -qF "home/.claude/review/run.md" "$r"
  for o in $(grep -oE '`home/[^`]+`' "$r" | tr -d '`'); do
    [ -f "$DOTFILES_DIR/$C/$o" ] || { echo "missing $o"; return 1; }
  done
}

@test "the module links skills, their scripts and agents" {
  stub_externals
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  [ "$(readlink "$HOME/.claude/skills/retro/SKILL.md")" = "$DOTFILES_DIR/$C/home/.claude/skills/retro/SKILL.md" ]
  [ -x "$HOME/.claude/skills/retro/pairs.sh" ]
  [ -x "$HOME/.claude/skills/retro/chunk.sh" ]
  [ -x "$HOME/.claude/skills/retro/harness-then.sh" ]
  [ -x "$HOME/.claude/skills/retro/harness-now.sh" ]
  [ -x "$HOME/.claude/skills/find-past-session/search.sh" ]
  [ "$(readlink "$HOME/.claude/agents/reviewer.md")" = "$DOTFILES_DIR/$C/home/.claude/agents/reviewer.md" ]
  [ "$(readlink "$HOME/.claude/review/run.md")" = "$DOTFILES_DIR/$C/home/.claude/review/run.md" ]
}

transcript_line() { # type role ts text
  jq -cn --arg t "$1" --arg r "$2" --arg ts "$3" --arg x "$4" \
    '{type:$t, timestamp:$ts, isSidechain:false, message:{role:$r, content:[{type:"text", text:$x}]}}'
}

@test "search.sh finds a phrase in a fixture transcript and caps output" {
  d="$HOME/.claude/projects/-tmp-proj"
  mkdir -p "$d"
  long="$(printf 'x%.0s' $(seq 1 300))"
  transcript_line user user 2026-03-04T10:00:00Z "we picked the Blue Harbor plan $long" >"$d/aaa.jsonl"
  transcript_line assistant assistant 2026-03-05T10:00:00Z "nothing to see" >>"$d/aaa.jsonl"
  transcript_line user user 2026-04-01T10:00:00Z "second phrasing: red dock" >"$d/bbb.jsonl"
  run bash "$S/find-past-session/search.sh" "blue harbor" "Red Dock"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "$output" == *"aaa  2026-03-04  "*"Blue Harbor plan"* ]]
  [[ "$output" == *"bbb  2026-04-01  second phrasing: red dock"* ]]
  [[ "$output" != *"nothing to see"* ]]
  for l in "${lines[@]}"; do
    t="${l#*  *  }"
    [ "${#t}" -le 200 ] || { echo "too long: ${#t}"; return 1; }
  done
  for i in $(seq 1 50); do transcript_line user user 2026-05-01T00:00:00Z "blue harbor again $i" >>"$d/ccc.jsonl"; done
  run bash "$S/find-past-session/search.sh" "blue harbor"
  [ "${#lines[@]}" -eq 30 ]
  run bash "$S/find-past-session/search.sh" "never said"
  [ -z "$output" ]
}

@test "search.sh reads text and commands, never tool results, and skips an excluded session" {
  d="$HOME/.claude/projects/-tmp-proj"
  mkdir -p "$d"
  jq -cn '{type:"user", timestamp:"2026-01-01T00:00:00Z", message:{role:"user", content:[{type:"tool_result", content:"secret harbor output"}]}}' >"$d/aaa.jsonl"
  jq -cn '{type:"assistant", timestamp:"2026-01-02T00:00:00Z", message:{role:"assistant", content:[{type:"tool_use", name:"Bash", input:{command:"grep harbor notes.txt", description:"look"}}]}}' >>"$d/aaa.jsonl"
  transcript_line user user 2026-01-03T00:00:00Z "harbor talk here" >"$d/self.jsonl"
  run bash "$S/find-past-session/search.sh" --exclude self "harbor"
  [ "$status" -eq 0 ]
  [ "$output" = "aaa  2026-01-02  grep harbor notes.txt" ]
}

@test "pairs.sh prints prompts and one reply per turn with its tool trail from a fixture transcript" {
  f="$HOME/t.jsonl"
  {
    jq -cn '{type:"user", timestamp:"T1", message:{role:"user", content:"why does the cache miss?"}}'
    jq -cn '{type:"assistant", timestamp:"T2", message:{role:"assistant", content:[{type:"thinking", thinking:"hmm"},{type:"text", text:"Because the key has the pid."},{type:"tool_use", id:"t1", name:"Bash", input:{command:"ls"}}]}}'
    jq -cn '{type:"user", timestamp:"T3", message:{role:"user", content:[{type:"tool_result", tool_use_id:"t1", content:"file list"}]}}'
    jq -cn '{type:"user", timestamp:"T4", isMeta:true, message:{role:"user", content:"<local-command-caveat>x"}}'
    jq -cn '{type:"user", timestamp:"T5", isSidechain:true, message:{role:"user", content:"subagent brief"}}'
    jq -cn '{type:"user", timestamp:"T6", message:{role:"user", content:"<task-notification>\n<task-id>1</task-id>"}}'
    jq -cn '{type:"user", timestamp:"T7", isCompactSummary:true, message:{role:"user", content:"This session is being continued"}}'
    jq -cn '{type:"attachment", timestamp:"T8"}'
    jq -cn '{type:"assistant", timestamp:"T9", message:{role:"assistant", content:[{type:"tool_use", id:"t2", name:"Read", input:{}}]}}'
    jq -cn '{type:"user", timestamp:"T10", message:{role:"user", content:[{type:"text", text:"ok udade"}]}}'
  } >"$f"
  run bash "$S/retro/pairs.sh" "$f"
  [ "$status" -eq 0 ]
  expected='{"i":0,"role":"user","kind":"prompt","ts":"T1","text":"why does the cache miss?"}
{"i":1,"role":"assistant","kind":"reply","ts":"T2","text":"Because the key has the pid.","tools":"Bash(ls), Read"}
{"i":2,"role":"user","kind":"prompt","ts":"T10","text":"ok udade"}'
  [ "$output" = "$expected" ]
}

@test "pairs.sh defaults to the newest transcript for the cwd" {
  mkdir -p "$HOME/my.proj"
  cd "$HOME/my.proj"
  d="$HOME/.claude/projects/$(pwd | tr '/._' '---')"
  mkdir -p "$d"
  jq -cn '{type:"user", timestamp:"T1", message:{role:"user", content:"old session"}}' >"$d/old.jsonl"
  jq -cn '{type:"user", timestamp:"T2", message:{role:"user", content:"new session"}}' >"$d/new.jsonl"
  touch -t 202601010000 "$d/old.jsonl"
  touch -t 202602010000 "$d/new.jsonl"
  run bash "$S/retro/pairs.sh"
  [ "$status" -eq 0 ]
  [ "$output" = '{"i":0,"role":"user","kind":"prompt","ts":"T2","text":"new session"}' ]
}

@test "pairs.sh resolves a session id to its newest transcript across projects" {
  a="$HOME/.claude/projects/-a"; b="$HOME/.claude/projects/-b"
  mkdir -p "$a" "$b"
  jq -cn '{type:"user", timestamp:"T1", message:{role:"user", content:"stale fork"}}' >"$a/s1.jsonl"
  jq -cn '{type:"user", timestamp:"T2", message:{role:"user", content:"live session"}}' >"$b/s1.jsonl"
  touch -t 202601010000 "$a/s1.jsonl"
  touch -t 202602010000 "$b/s1.jsonl"
  run bash "$S/retro/pairs.sh" s1
  [ "$status" -eq 0 ]
  [ "$output" = '{"i":0,"role":"user","kind":"prompt","ts":"T2","text":"live session"}' ]
}

@test "pairs.sh fails on an unknown session id" {
  mkdir -p "$HOME/.claude/projects/-a"
  run bash "$S/retro/pairs.sh" nope
  [ "$status" -ne 0 ]
}

@test "a colleague review never asks the author to split the PR" {
  grep -qF "never asks the author to split the PR" "$DOTFILES_DIR/$C/home/.claude/review/run.md"
  run grep -F "as a should-fix finding" "$DOTFILES_DIR/$C/home/.claude/review/run.md"
  [ "$status" -eq 1 ] || false
}

@test "voice-draft warns about the Slack connector byline" {
  grep -qF "Sent using @Claude" "$DOTFILES_DIR/modules/claude/home/.claude/skills/voice-draft/SKILL.md"
}

@test "the review engine follows a repo's REVIEW.md and has a fresh reviewer refute each finding" {
  f="$DOTFILES_DIR/$C/home/.claude/review/run.md"
  grep -qF "REVIEW.md" "$f"
  grep -qF 'One fresh `reviewer` per batch' "$f"
}
