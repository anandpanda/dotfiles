load helper
C="modules/claude"
SKILLS="explain grill phase-close pr-description voice-draft review-pr research find-past-session handoff retro scout"
USER_ONLY="phase-close handoff voice-draft retro scout"
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
  [ "$(find "$S" -name SKILL.md | wc -l | tr -d ' ')" -eq 11 ]
}

@test "side-effect skills disable model invocation" {
  for s in $SKILLS; do
    v="$(field "$S/$s/SKILL.md" disable-model-invocation)"
    case " $USER_ONLY " in
      *" $s "*) [ "$v" = true ] || { echo "model can invoke: $s"; return 1; } ;;
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

@test "each skill ships a trigger eval with at least half negatives" {
  for s in $SKILLS; do
    e="$S/$s/evals/trigger.json"
    jq -e 'type=="array" and length>=6
      and all(.[]; (.query|type)=="string" and (.query|length)>0 and (.should_trigger|type)=="boolean")
      and ((map(select(.should_trigger==false))|length)*2 >= length)
      and any(.[]; .should_trigger==true)' "$e" >/dev/null || { echo "bad eval: $s"; return 1; }
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
  for a in reviewer researcher worker; do
    [ "$(head -1 "$A/$a.md")" = "---" ]
    [ "$(field "$A/$a.md" name)" = "$a" ]
    [ -n "$(field "$A/$a.md" description)" ]
  done
}

@test "every agent body carries the subagent standing rules" {
  for a in reviewer researcher worker; do
    for p in "Nothing fake" "Skip no check" "Stay on the task" "Return the path and the count"; do
      grep -qF "$p" "$A/$a.md" || { echo "$a missing: $p"; return 1; }
    done
  done
  grep -qF "Write your findings to the file" "$A/researcher.md"
  grep -qF "Write your findings to the file" "$A/worker.md"
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
  grep -qF "Merge risk" "$f"
  grep -qF "What did not change" "$f"
  grep -qF "No AI attribution" "$f"
}

@test "review-pr finds, refutes and drafts replies through voice-draft" {
  f="$S/review-pr/SKILL.md"
  for p in "refute" "a line you read" "Comment ledger" "voice-draft" "Never post"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "phase-close carries doc-drift and the anti-cheat contract" {
  f="$S/phase-close/SKILL.md"
  for p in "doc-drift" "anti-cheat contract" "What I got wrong" "STATUS" "Yours to do" "previous count" "reviewer"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
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
  for s in pr-description review-pr voice-draft explain phase-close retro scout; do
    grep -qF "home/.claude/skills/$s/SKILL.md" "$r" || { echo "no resolver row: $s"; return 1; }
  done
  grep -qF "home/.claude/agents/reviewer.md" "$r"
  for o in $(grep -oE '`home/[^`]+`' "$r" | tr -d '`'); do
    [ -f "$DOTFILES_DIR/$C/$o" ] || { echo "missing $o"; return 1; }
  done
}

@test "the module links skills, their scripts and agents" {
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  [ "$(readlink "$HOME/.claude/skills/retro/SKILL.md")" = "$DOTFILES_DIR/$C/home/.claude/skills/retro/SKILL.md" ]
  [ -x "$HOME/.claude/skills/retro/pairs.sh" ]
  [ -x "$HOME/.claude/skills/find-past-session/search.sh" ]
  [ "$(readlink "$HOME/.claude/agents/reviewer.md")" = "$DOTFILES_DIR/$C/home/.claude/agents/reviewer.md" ]
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

@test "pairs.sh prints only prompts and assistant text from a fixture transcript" {
  f="$HOME/t.jsonl"
  {
    jq -cn '{type:"user", timestamp:"T1", message:{role:"user", content:"why does the cache miss?"}}'
    jq -cn '{type:"assistant", timestamp:"T2", message:{role:"assistant", content:[{type:"thinking", thinking:"hmm"},{type:"text", text:"Because the key has the pid."},{type:"tool_use", name:"Bash", input:{command:"ls"}}]}}'
    jq -cn '{type:"user", timestamp:"T3", message:{role:"user", content:[{type:"tool_result", content:"file list"}]}}'
    jq -cn '{type:"user", timestamp:"T4", isMeta:true, message:{role:"user", content:"<local-command-caveat>x"}}'
    jq -cn '{type:"user", timestamp:"T5", isSidechain:true, message:{role:"user", content:"subagent brief"}}'
    jq -cn '{type:"user", timestamp:"T6", message:{role:"user", content:"<task-notification>\n<task-id>1</task-id>"}}'
    jq -cn '{type:"user", timestamp:"T7", isCompactSummary:true, message:{role:"user", content:"This session is being continued"}}'
    jq -cn '{type:"attachment", timestamp:"T8"}'
    jq -cn '{type:"assistant", timestamp:"T9", message:{role:"assistant", content:[{type:"tool_use", name:"Read", input:{}}]}}'
    jq -cn '{type:"user", timestamp:"T10", message:{role:"user", content:[{type:"text", text:"ok udade"}]}}'
  } >"$f"
  run bash "$S/retro/pairs.sh" "$f"
  [ "$status" -eq 0 ]
  expected='{"role":"user","ts":"T1","text":"why does the cache miss?"}
{"role":"assistant","ts":"T2","text":"Because the key has the pid."}
{"role":"user","ts":"T10","text":"ok udade"}'
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
  [ "$output" = '{"role":"user","ts":"T2","text":"new session"}' ]
}
