#!/usr/bin/env bash
# Blocks reading, searching or printing secrets; the allowed route is with-secrets or sops exec-env.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

ROUTE="use \`with-secrets <cmd>\` (or \`sops exec-env\`) so the value reaches the command, never the transcript"
SECRET_VAR='[A-Za-z0-9_]*(TOKEN|SECRET|PASSW|KEY|CREDENTIAL)[A-Za-z0-9_]*'
SLICE_RE='\$\{'"$SECRET_VAR"'(:[[:space:]]*-?[0-9]|[#%/^,])'
PRINT_RE='(^|[^A-Za-z0-9_])(echo|printf)[^|;&]*\$\{?'"$SECRET_VAR"
DECODE_RE='\$\{?'"$SECRET_VAR"'[^;&]*\|[[:space:]]*(od|xxd|hexdump|base64|cut|rev|fold|strings|head|tail)'

secret_path() {
  local p="$1" base="${1##*/}" hit=1
  shopt -s nocasematch
  case "$p" in
    */.secrets/* | */.secrets | .secrets/* | .secrets | */.aws/sso/cache* | .aws/sso/cache*) hit=0 ;;
    *)
      case "$base" in
        .env.example | .env.sample | .env.template) ;;
        .env | .env.* | id_rsa | id_ed25519 | *backup*code* | *recovery*code* | *.pem | *.key) hit=0 ;;
      esac
      ;;
  esac
  shopt -u nocasematch
  return "$hit"
}

check_path() {
  [ -n "$1" ] || return 0
  secret_path "$(hook_norm_path "$1")" && hook_block "Blocked: $1 holds secrets. $ROUTE."
  return 0
}

check_bash() {
  local seg w
  printf '%s' "$1" | hook_has_token &&
    hook_block "Blocked: the command carries a literal token. Store it in ~/.secrets and $ROUTE."
  printf '%s' "$1" | grep -Eiq "$SLICE_RE|$PRINT_RE|$DECODE_RE" &&
    hook_block "Blocked: printing, slicing or decoding a secret variable leaks it. $ROUTE."
  set -f
  while IFS= read -r seg; do
    seg="${seg#"${seg%%[![:space:]]*}"}"
    case "$seg" in with-secrets | with-secrets\ * | sops\ exec-env\ *) continue ;; esac
    for w in $(printf '%s' "$seg" | tr -d "\"'" | tr '<>=' '   '); do
      secret_path "$w" && hook_block "Blocked: $w holds secrets. $ROUTE."
    done
  done < <(printf '%s\n' "$1" | tr '|&;()`' '[\n*]')
  return 0
}

hook_input
case "$(hook_field .tool_name)" in
  Read) check_path "$(hook_field .tool_input.file_path)" ;;
  Grep)
    check_path "$(hook_field .tool_input.path)"
    glob="$(hook_field .tool_input.glob)"
    check_path "${glob//\*/}"
    ;;
  Bash) check_bash "$(hook_field .tool_input.command)" ;;
esac
exit 0
