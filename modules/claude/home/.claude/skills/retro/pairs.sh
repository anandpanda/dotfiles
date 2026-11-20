#!/usr/bin/env bash
# Print one session as JSON lines {i, role, kind, ts, text, tools?}: what Anand typed, rejected, answered or interrupted, and each Claude turn as its text plus a one-line tool trail.
# Takes a transcript path, a session id (a resumed session can exist in several project folders, so the newest copy wins), or nothing for the cwd's newest session.
# Stops on a content block type it does not know, because the transcript format changes between Claude Code versions.
# A torn line (two writers on one file) is skipped and named in an unreadable entry.
set -euo pipefail

newest_transcript() {
  local dir f newest=""
  dir="$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
  for f in "$dir"/*.jsonl; do
    [ -e "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  [ -n "$newest" ] || {
    echo "no transcript for $(pwd) in $dir" >&2
    return 1
  }
  echo "$newest"
}

newest_by_id() {
  local f newest=""
  for f in "$HOME"/.claude/projects/*/"$1".jsonl; do
    [ -e "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  [ -n "$newest" ] || {
    echo "no transcript for session $1" >&2
    return 1
  }
  echo "$newest"
}

case "${1:-}" in
  "") transcript="$(newest_transcript)" ;;
  */* | *.jsonl) transcript="$1" ;;
  *) transcript="$(newest_by_id "$1")" ;;
esac

jq -n -R -c '
  def known_blocks: ["text", "tool_use", "tool_result", "thinking", "redacted_thinking", "image", "fallback"];
  def noise: "<(system-reminder|ide_opened_file|ide_selection)>[\\s\\S]*?</(system-reminder|ide_opened_file|ide_selection)>";
  def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
  def clean: gsub(noise; "") | trim;
  def one_line: gsub("\\s+"; " ") | trim | .[0:80];
  def blocks: if type == "string" then [{type: "text", text: .}] else . end;
  def checked: (map(.type) - known_blocks) as $unknown
    | if ($unknown | length) > 0 then error("unknown content block type: \($unknown[0])") else . end;

  def call_name: .name + (
    (.input.command // (.input.file_path | values | split("/") | last) // .input.pattern
      // .input.skill // .input.description // .input.url // .input.query)
    | if . == null then "" else "(\(tostring | one_line))" end);

  def trail: reduce .[] as $t ([]; if (last // [null])[0] == $t then .[-1][1] += 1 else . + [[$t, 1]] end)
    | map(.[0] + (if .[1] > 1 then " ×\(.[1])" else "" end)) | join(", ");

  def typed($content): ($content | blocks) as $b
    | ([$b[] | select(.type == "image")] | length) as $images
    | ([$b[] | select(.type == "text") | .text | clean | select(. != "")] | join("\n")) as $text
    | ([range($images) | "[image] "] | join("")) + $text;

  def result_text: .content | if type == "array" then map(.text // "") | join("") else (. // "") end;

  def tool_result_entry($record; $labels):
    ($labels[.tool_use_id] // "a tool call") as $call
    | result_text as $text
    | if (.is_error == true) and ($text | test("doesn.t want to proceed")) then
        if $text | test("stopped while running") then {kind: "stopped", text: $call}
        else ([$text | capture("reason for the rejection:\\s*(?<why>[\\s\\S]*)") | .why | trim][0]) as $why
          | {kind: "rejection", text: ($call + (if $why then ": " + $why else "" end))}
        end
      elif ($record.toolUseResult | type) == "object" and ($record.toolUseResult | has("answers")) then
        {kind: "answer", text: ($record.toolUseResult.answers | to_entries | map("\(.key) → \(.value)") | join("\n"))}
      else empty end;

  def string_entry:
    if test("^<command-(name|message)>") then
      {kind: "command", text: ([capture("<command-name>(?<n>[^<]*)</command-name>").n,
        ([capture("<command-args>(?<a>[^<]*)</command-args>").a][0] // "")] | join(" ") | trim)}
    elif test("^<(task-notification|local-command-|bash-stdout|bash-stderr)") then empty
    else (clean | select(. != "") | {kind: "prompt", text: .}) end;

  def user_entries($labels):
    . as $record
    | if .isSidechain == true or .isMeta == true or .isCompactSummary == true then []
      elif (.message.content | type) == "string" then [.message.content | string_entry]
      else (.message.content | checked) as $b
        | [$b[] | select(.type == "tool_result") | tool_result_entry($record; $labels)]
          + if any($b[]; .type == "text" and (.text | startswith("[Request interrupted"))) then [{kind: "interrupt", text: ""}]
            else [typed($b) | select(. != "") | {kind: "prompt", text: .}] end
      end
    | map(. + {role: "user", ts: $record.timestamp});

  def entries($labels):
    if .torn then [{role: "system", kind: "unreadable", ts: null, text: "transcript line \(.torn) could not be parsed"}]
    elif .type == "user" then user_entries($labels)
    elif .type == "attachment" and .attachment.type == "queued_command" and .attachment.origin.kind == "human" then
      .timestamp as $ts | [typed(.attachment.prompt) | select(. != "") | {role: "user", kind: "queued", ts: $ts, text: .}]
    elif .type == "system" and .subtype == "compact_boundary" then [{role: "system", kind: "compacted", ts: .timestamp, text: ""}]
    else [] end;

  def reply: select(. != null and ((.texts | length) > 0 or (.tools | length) > 0))
    | {role: "assistant", kind: "reply", ts, text: (.texts | join("\n") | trim)}
      + (.tools | trail | if . == "" then {} else {tools: .} end);

  foreach ((inputs | try fromjson catch {torn: input_line_number}), {end: true}) as $r (
    {i: 0, turn: null, labels: {}, out: []};
    if $r.end then .out = [.turn | reply] | .turn = null
    elif $r.type == "assistant" and ($r.isSidechain != true) then
      ($r.message.content | blocks | checked) as $b
      | .out = []
      | .turn = ((.turn // {ts: $r.timestamp, texts: [], tools: []})
          | .texts += [$b[] | select(.type == "text") | .text | trim | select(. != "")]
          | .tools += [$b[] | select(.type == "tool_use") | call_name])
      | .labels += ([$b[] | select(.type == "tool_use") | {key: .id, value: call_name}] | from_entries)
    else
      .labels as $labels
      | ($r | entries($labels)) as $new
      | if ($new | length) == 0 then .out = []
        else .out = ([.turn | reply] + $new) | .turn = null | .labels = {} end
    end
    | .i as $start
    | .out = [.out | to_entries[] | {i: ($start + .key), role: .value.role, kind: .value.kind, ts: .value.ts, text: .value.text}
        + (.value | if .tools then {tools} else {} end)]
    | .i += (.out | length);
    .out[]
  )
' "$transcript"
