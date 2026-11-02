#!/usr/bin/env bash
# Print the assistant text just before and just after one entry of pairs.sh output.
set -euo pipefail

pairs="$1"
index="$2"

jq -r --slurp --argjson i "$index" '
  . as $all
  | def show($k): "---- \($all[$k].role) [\($k)] \($all[$k].ts)\n\($all[$k].text)";
  ([range(0; $i)] | map(select($all[.].role == "assistant")) | last) as $before
  | ([range($i + 1; $all | length)] | map(select($all[.].role == "assistant")) | first) as $after
  | [$before, $i, $after] | map(select(. != null) | show(.)) | join("\n")
' "$pairs"
