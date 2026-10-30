#!/usr/bin/env bash
# Shared helpers for Claude Code hooks: read the input once, pull fields, block, add context, normalise paths.

hook_has_token() {
  grep -Eq '(^|[^A-Za-z0-9_])((AKIA|ASIA)[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[abp]-[A-Za-z0-9-]{10,}|glsa_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9_-]{20,}|Bearer [A-Za-z0-9._~+/=-]{20,})|-----BEGIN [A-Z ]*PRIVATE KEY-----'
}

hook_block() {
  printf '%s\n' "$1" >&2
  exit 2
}

hook_input() {
  command -v jq >/dev/null 2>&1 || hook_block "hook input unreadable: jq is missing (brew install jq)"
  HOOK_JSON="$(cat)" || hook_block "hook input unreadable"
  printf '%s' "$HOOK_JSON" | jq -e 'type == "object"' >/dev/null 2>&1 || hook_block "hook input unreadable"
}

hook_field() {
  printf '%s' "${HOOK_JSON:-}" | jq -r "($1) // empty"
}

hook_context() {
  jq -cn --arg e "$1" --arg t "$2" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
}

hook_norm_path() {
  local p="$1" base
  p="${p//\"/}"
  p="${p//\'/}"
  case "$p" in
    \~ | \~/*) p="$HOME${p#\~}" ;;
    \$HOME | \$HOME/*) p="$HOME${p#\$HOME}" ;;
    \$\{HOME\} | \$\{HOME\}/*) p="$HOME${p#\$\{HOME\}}" ;;
  esac
  case "$p" in
    /*) ;;
    *)
      base="$(hook_field .cwd 2>/dev/null || true)"
      p="${base:-$PWD}/$p"
      ;;
  esac
  printf '%s\n' "$p"
}
