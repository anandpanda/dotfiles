#!/usr/bin/env bash
# Blocks reading, searching or printing secrets; with-secrets and sops exec-env are the route and are checked too.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

ROUTE="use \`with-secrets <cmd>\` (or \`sops exec-env\`) so the value reaches the command, never the transcript"
NAME='([A-Z0-9]+_)*(TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|KEY|CREDENTIALS?)(_[A-Z0-9]+)*'
REF='\$\{?'"$NAME"'([^A-Za-z0-9_]|$)'
LEAK_RE='\$\{'"$NAME"'(:[[:space:]]*-?[0-9]|[#%/^,])'
LEAK_RE+="|(^|[^A-Za-z0-9_])(echo|printf)[^|;&]*$REF"
LEAK_RE+="|(^|[^A-Za-z0-9_])printenv[[:space:]]+$NAME([^A-Za-z0-9_]|\$)"
LEAK_RE+="|${REF}[^;&]*\\|[[:space:]]*(od|xxd|hexdump|base64|cut|rev|fold|strings|head|tail|tee|cat)"
LEAK_RE+="|<<<[[:space:]]*\"?$REF"
LEAK_RE+="|(^|[;&|(\`][[:space:]]*)(export[[:space:]]+|local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\"?$REF"
GLOB_NAMES=".env .env.local .envrc .netrc .git-credentials credentials id_rsa id_ed25519 id_ecdsa id_dsa x.pem x.key backup-codes.txt recovery-codes.txt"
SPLIT_AWK='
function put(x) {
  if (lvl == 1) printf "%s", x
  else acc[lvl] = acc[lvl] x
}
function plain(line) {
  gsub(/["\047\\]/, "", line)
  gsub(/[|&;]/, "\n", line)
  gsub(/[()\140]/, " ", line)
  gsub(/>/, " > ", line)
  gsub(/</, " < ", line)
  return line
}
function closing(s, i, n, op, cl,   d, c, q) {
  d = 1
  q = ""
  for (; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") {
      if (c == q) q = ""
      else if (c == "\\" && q == "\"") i++
      continue
    }
    if (c == "\\") { i++; continue }
    if (cl != "\140" && (c == "\047" || c == "\"")) { q = c; continue }
    if (op != cl && c == op) d++
    else if (c == cl && --d == 0) return i
  }
  return n + 1
}
function subst(inner,   r) {
  r = norm(inner)
  extra = extra "\n" r
  gsub(/[ \t\n\001]+/, "\003", r)
  gsub(/\002/, "", r)
  put("\002" r "\002")
}
function norm(s,   n, i, c, nx, q, hd, j, k, t, line, r) {
  lvl++
  acc[lvl] = ""
  n = length(s)
  q = ""
  hd = ""
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    nx = substr(s, i + 1, 1)
    if (q == "\047") {
      if (c == "\047") q = ""
      else put(index(" \t\n", c) ? "\001" : c)
      continue
    }
    if (q == "\"" && c == "\"") { q = ""; continue }
    if (c == "\\") {
      if (nx != "\n") put(index(" \t", nx) ? "\001" : nx)
      i++
      continue
    }
    if (nx == "(" && (c == "\044" || (q == "" && (c == "<" || c == ">")))) {
      j = closing(s, i + 2, n, "(", ")")
      subst(substr(s, i + 2, j - i - 2))
      i = j
      continue
    }
    if (c == "\140") {
      j = closing(s, i + 1, n, "\140", "\140")
      subst(substr(s, i + 1, j - i - 1))
      i = j
      continue
    }
    if (q == "\"") { put(index(" \t\n", c) ? "\001" : c); continue }
    if (c == "\047" || c == "\"") { q = c; continue }
    if (c == "#" && (i == 1 || index(" \t\n;&|(", substr(s, i - 1, 1)))) {
      while (i < n && substr(s, i + 1, 1) != "\n") i++
      continue
    }
    if (c == ">") {
      put(" > ")
      while (index(">&|", substr(s, i + 1, 1)) && i < n) i++
      continue
    }
    if (c == "&" && nx == ">") continue
    if (c == "<") {
      k = i
      while (substr(s, k + 1, 1) == "<") k++
      if (k - i == 1) {
        j = k + 1
        if (substr(s, j, 1) == "-") j++
        while (index(" \t", substr(s, j, 1)) && j <= n) j++
        t = ""
        while (j <= n && !index(" \t\n;&|<>()", substr(s, j, 1))) { t = t substr(s, j, 1); j++ }
        gsub(/["\047\\]/, "", t)
        hd = t
      }
      put(" < ")
      i = k
      continue
    }
    if (c == "\n" && hd != "") {
      put("\n")
      while (i < n) {
        j = index(substr(s, i + 1), "\n")
        if (j == 0) j = n - i + 1
        line = substr(s, i + 1, j - 1)
        i += j
        t = line
        sub(/^\t+/, "", t)
        if (t == hd) break
        put(plain(line) "\n")
      }
      hd = ""
      continue
    }
    if (index("|&;()\n", c)) { put("\n"); continue }
    put(c)
  }
  r = acc[lvl]
  lvl--
  return r
}
BEGIN {
  while ((getline line) > 0) s = s line "\n"
  gsub("[\044][{]HOME[}]", "\044HOME", s)
  norm(s)
  printf "\n%s\n", extra
}
'
SP=$'\001'
SUBC=$'\002'
SUBSEP_=$'\003'
XARGS=0
PHYS=""
ABS=""

secret_path() {
  local base="${1##*/}" hit=1
  shopt -s nocasematch
  case "$1" in
    */.secrets/* | */.secrets | */.aws/sso/cache | */.aws/sso/cache/* | */.aws/credentials | /proc/*/environ) hit=0 ;;
    *)
      case "$base" in
        .env*.example | .env*.sample | .env*.template) ;;
        .env | .env.* | .envrc | .netrc | .git-credentials | id_rsa | id_ed25519 | id_ecdsa | id_dsa | *backup*code* | *recovery*code* | *.pem | *.key) hit=0 ;;
      esac
      ;;
  esac
  shopt -u nocasematch
  return "$hit"
}

physical() {
  local d b t here="$PWD"
  PHYS=""
  [ -e "$1" ] || return 0
  d="${1%/*}"
  b="${1##*/}"
  if [ -L "$1" ]; then
    t="$(readlink "$1")"
    case "$t" in /*) ;; *) t="$d/$t" ;; esac
    d="${t%/*}"
    b="${t##*/}"
  fi
  CDPATH='' cd -P "${d:-/}" 2>/dev/null || return 0
  PHYS="$PWD/$b"
  cd "$here"
}

absolute() {
  case "$1" in
    \~ | \~/*) ABS="$HOME${1#\~}" ;;
    \$HOME | \$HOME/*) ABS="$HOME${1#\$HOME}" ;;
    /*) ABS="$1" ;;
    *) ABS="$CWD/$1" ;;
  esac
}

is_secret() {
  local v a m t x
  case "$1" in
    *"$SUBC"*)
      if is_secret "${1%%"$SUBC"*}X${1##*"$SUBC"}"; then return 0; fi
      t="${1#*"$SUBC"}"
      t="${t%"$SUBC"*}"
      for x in ${t//$SUBSEP_/ }; do
        if is_secret "$x"; then return 0; fi
      done
      return 1
      ;;
  esac
  v="${1##*=}"
  v="${v#@}"
  v="${v//$SP/ }"
  case "$v" in "" | -*) return 1 ;; esac
  absolute "$v"
  a="$ABS"
  secret_path "$a" && return 0
  case "$a" in
    *[*?[]*)
      case "$a" in *.secr* | *secrets* | *.SECR* | *SECRETS*) return 0 ;; esac
      set +f
      shopt -s nullglob dotglob
      for m in $a; do
        if secret_path "$m"; then
          set -f
          shopt -u nullglob dotglob
          return 0
        fi
      done
      set -f
      shopt -u nullglob dotglob
      return 1
      ;;
  esac
  physical "$a"
  [ -n "$PHYS" ] && secret_path "$PHYS"
}

block_path() { hook_block "Blocked: $1 holds secrets and this command would read or send it. $ROUTE."; }
block_dump() { hook_block "Blocked: this prints the values with-secrets loads. Run the command that needs them, never an environment dump."; }

set_cwd() {
  local v m
  absolute "$1"
  v="$ABS"
  case "$v" in
    *[*?[]*)
      set +f
      shopt -s nullglob dotglob
      for m in $v; do
        v="$m"
        break
      done
      set -f
      shopt -u nullglob dotglob
      ;;
  esac
  CWD="$v"
  cd "$CWD" 2>/dev/null || true
}

scan_segment() {
  local w b ws="$1" shell=0 wrap=0 envd=0 reader=0 copy="" pend=0 prev="" src="" srcsec=0 nops=0 target=0 tsec=0 arch=0 curl=0 sops=0 find=0 found=0 fexec=0 grep=0 pat=0 next=""
  shift
  while [ $# -gt 0 ]; do
    case "$1" in "$SUBC"*)
      reader=1
      break
      ;;
    esac
    b="${1##*/}"
    case "$b" in
      bash | sh | zsh | dash | ksh | eval)
        wrap=1
        envd=0
        shell=1
        if [ "$b" = eval ]; then
          shift
          scan_command "$*" "$ws"
          return 0
        fi
        ;;
      sudo | command | exec | nohup | time | builtin | nice | timeout | xargs | stdbuf)
        wrap=1
        envd=0
        ;;
      env)
        wrap=1
        envd=1
        ;;
      with-secrets)
        ws=1
        envd=0
        ;;
      sops)
        if [ "${2:-}" != exec-env ] || [ $# -lt 3 ]; then break; fi
        shift 2
        ws=1
        ;;
      *=*) ;;
      -*c)
        if [ "$shell" = 1 ]; then
          scan_command "${2:-}" "$ws"
          return 0
        fi
        if [ "$wrap" = 0 ]; then break; fi
        ;;
      -* | [0-9]*) if [ "$wrap" = 0 ]; then break; fi ;;
      *) break ;;
    esac
    shift
  done
  if [ "$ws" = 1 ]; then
    b="${1:-}"
    case "${b##*/}" in
      printenv | compgen) block_dump ;;
      set) if [ $# -eq 1 ]; then block_dump; fi ;;
      export | declare | typeset) case "${2:--p}" in -p | -x | -px | -xp) block_dump ;; esac ;;
      "" | "<" | ">") if [ "$envd" = 1 ]; then block_dump; fi ;;
    esac
  fi
  case "${1:-}" in
    cd | pushd)
      shift
      case "${1:-}" in -P | -L) shift ;; esac
      set_cwd "${1:-$HOME}"
      return 0
      ;;
    source | .) reader=1 ;;
  esac
  for w; do
    if [ -n "$next" ]; then
      case "$next" in
        in | tgt) if is_secret "$w"; then block_path "$w"; fi ;;
        tdir) if is_secret "$w"; then tsec=1; fi ;;
      esac
      next=""
      continue
    fi
    case "$w" in
      "<") next=in && continue ;;
      ">") next=out && continue ;;
    esac
    if [ "$grep" = 1 ]; then
      case "$w" in
        -e | --regexp) pat=1 && next=skip && continue ;;
        -f | --file) pat=1 && next=tgt && continue ;;
        -A | -B | -C | -m | -d | -D | -g | -t | -T | -j | -M | --glob | --type | --type-not | --max-count | --context | --after-context | --before-context) next=skip && continue ;;
        -e* | --regexp=*) pat=1 && continue ;;
        -*) continue ;;
      esac
      if [ "$pat" = 0 ]; then
        pat=1
        continue
      fi
      if is_secret "$w"; then block_path "$w"; fi
      continue
    fi
    if [ -n "$copy" ]; then
      if [ "$copy" != rsync ]; then
        case "$w" in
          -t | --target-directory | -[!-]*t) target=1 && next=tdir && continue ;;
          --target-directory=*)
            target=1
            if is_secret "${w#*=}"; then tsec=1; fi
            continue
            ;;
          -t?* | -[!-]*t?*)
            target=1
            if is_secret "${w#*t}"; then tsec=1; fi
            continue
            ;;
        esac
      fi
      case "$w" in -*) continue ;; esac
      nops=$((nops + 1))
      if [ "$pend" = 1 ]; then
        srcsec=1
        src="$prev"
      fi
      pend=0
      if is_secret "$w"; then
        pend=1
        prev="$w"
      fi
      continue
    fi
    case "$w" in
      -d | --decrypt | decrypt) if [ "$sops" = 1 ]; then reader=1; fi ;;
      -exec | -execdir | -ok | -okdir) fexec=1 ;;
      -T | --upload-file) if [ "$curl" = 1 ]; then next=tgt && continue; fi ;;
      -C) if [ "$arch" = 1 ]; then next=skip && continue; fi ;;
    esac
    b="${w##*/}"
    case "$b" in
      grep | egrep | fgrep | rg | ag)
        reader=1
        grep=1
        continue
        ;;
      cat | less | more | head | tail | sed | awk | gawk | source | base64 | xxd | od | hexdump | strings | bat | nl | tac | sort | uniq | cut | diff | cmp | jq | yq | python | python3 | node | ruby | perl | php)
        reader=1
        continue
        ;;
      cp | scp | rsync | install | ln) copy="$b" && continue ;;
      tar | zip | 7z) arch=1 && continue ;;
      curl | wget) curl=1 && continue ;;
      sops) sops=1 && continue ;;
      find) find=1 && continue ;;
    esac
    if [ "$reader$arch$curl$find" = 0000 ]; then continue; fi
    if is_secret "$w"; then
      if [ "$reader" = 1 ] || [ "$arch" = 1 ]; then block_path "$w"; fi
      case "$curl$w" in 1*@*) block_path "$w" ;; esac
      found=1
    fi
  done
  if [ -n "$copy" ]; then
    if [ "$target" = 1 ]; then
      if [ "$tsec" = 0 ] && [ "$srcsec$pend" != 00 ]; then block_path "${src:-$prev}"; fi
    elif [ "$copy$nops$pend" = ln11 ]; then
      block_path "$prev"
    elif [ "$srcsec$pend" = 10 ]; then
      block_path "$src"
    fi
  fi
  if [ "$find$found" = 11 ] && [ "$fexec$XARGS" != 00 ]; then block_path "a secret path found by find"; fi
  return 0
}

check_bash() {
  if hook_has_token <<<"$1"; then hook_block "Blocked: the command carries a literal token. Store it in ~/.secrets and $ROUTE."; fi
  if grep -Eq "$LEAK_RE" <<<"$1"; then hook_block "Blocked: printing, slicing, copying or decoding a secret variable leaks it. $ROUTE."; fi
  scan_command "$1" 0
}

scan_command() {
  local s words
  s="$(awk "$SPLIT_AWK" <<<"${1//$SP/ }")"
  case "$s" in *xargs*) XARGS=1 ;; esac
  set -f
  while read -r -a words; do scan_segment "$2" "${words[@]+"${words[@]}"}"; done <<<"$s"
  return 0
}

check_path() {
  local p
  [ -n "$1" ] || return 0
  p="$(hook_norm_path "$1")"
  physical "$p"
  if secret_path "$p" || { [ -n "$PHYS" ] && secret_path "$PHYS"; }; then hook_block "Blocked: $1 holds secrets. $ROUTE."; fi
  return 0
}

check_glob() {
  local piece base letters re c
  [ -n "$1" ] || return 0
  case "$1" in *[Ss][Ee][Cc][Rr]* | *sso/cache*) hook_block "Blocked: glob $1 reaches secrets. $ROUTE." ;; esac
  set -f
  for piece in ${1//[\{\},]/ }; do
    base="${piece##*/}"
    letters="${base//[^A-Za-z0-9_]/}"
    [ "${#letters}" -ge 2 ] || continue
    re="${base//./\\.}"
    re="${re//\*/.*}"
    re="^${re//\?/.}\$"
    for c in $GLOB_NAMES; do
      if [[ $c =~ $re ]]; then hook_block "Blocked: glob $1 matches secret files like $c. $ROUTE."; fi
    done
  done
  return 0
}

hook_input
CWD="$(hook_field .cwd)"
CWD="${CWD:-$PWD}"
cd "$CWD" 2>/dev/null || true
case "$(hook_field .tool_name)" in
  Read) check_path "$(hook_field .tool_input.file_path)" ;;
  Grep)
    check_path "$(hook_field .tool_input.path)"
    check_glob "$(hook_field .tool_input.glob)"
    ;;
  Bash) check_bash "$(hook_field .tool_input.command)" ;;
esac
exit 0
