#!/usr/bin/env bash
# Split pairs.sh output into chunk files cut only at Anand's turns, each at most max_bytes unless one turn alone is larger.
# Every chunk after the first opens with the previous chunk's last Claude reply, marked context:true, so a reader sees what he answered.
# Prints one line per chunk: its path, then the first and last i of its own lines, tab-separated.
set -euo pipefail

pairs="$1"
dir="$2"
max_bytes="${3:-80000}"
mkdir -p "$dir"

jq -n -r --argjson max "$max_bytes" '
  def bytes: tojson | utf8bytelength + 1;
  [inputs]
  | reduce .[] as $e ([]; if $e.role == "user" or length == 0 then . + [[$e]] else .[-1] += [$e] end)
  | reduce .[] as $turn ({chunks: [], size: 0};
      ($turn | map(bytes) | add) as $n
      | if (.chunks | length) == 0 or .size + $n > $max then .chunks += [$turn] | .size = $n
        else .chunks[-1] += $turn | .size += $n end)
  | .chunks as $chunks
  | range($chunks | length) as $k
  | ((if $k > 0 then [$chunks[$k - 1][] | select(.role == "assistant")] | last else null end)
      | if . then [. + {context: true}] else [] end) + $chunks[$k]
  | .[]
  | "\($k + 1)\t\(if .context then "" else .i end)\t\(tojson)"
' "$pairs" | awk -F'\t' -v dir="$dir" '
  function report() { if (file) { close(file); print file "\t" first "\t" last } }
  $1 != current { report(); current = $1; file = sprintf("%s/chunk-%03d.jsonl", dir, $1); first = "" }
  $2 != "" { if (first == "") first = $2; last = $2 }
  { sub(/^[^\t]*\t[^\t]*\t/, ""); print > file }
  END { report() }
'
