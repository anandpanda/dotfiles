#!/usr/bin/env bash
# Profile files are a TOML subset: modules = [...], extends = "name", overlay = true.

profiles_dir() { echo "${DOTFILES_PROFILES:-$DOTFILES_DIR/profiles}"; }

profile_file() {
  local f
  f="$(profiles_dir)/$1.toml"
  [ -f "$f" ] || {
    log_fail "unknown profile: $1"
    return 1
  }
  echo "$f"
}

_toml_string() { # FILE KEY -> value of key = "value"
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}
_toml_bool_true() { # FILE KEY -> 0 if key = true
  grep -Eq "^[[:space:]]*$2[[:space:]]*=[[:space:]]*true" "$1"
}
_toml_list() { # FILE KEY -> items one per line; the list may span lines until the closing ]
  awk -v key="$2" '
    !inlist && $0 ~ "^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\\[" { sub(/^[^[]*\[/, ""); inlist = 1 }
    inlist { line = $0; if (line ~ /\]/) { sub(/\].*/, "", line); done = 1 }
             n = split(line, parts, ","); for (i = 1; i <= n; i++) { gsub(/[[:space:]"]/, "", parts[i]); if (parts[i] != "") print parts[i] }
             if (done) exit }
  ' "$1"
}

# Prints the chain root-first: base child ...
_profile_chain() {
  local name="$1" seen="${2:-}" file parent
  case " $seen " in *" $name "*)
    log_fail "profile extends cycle at: $name"
    return 1
    ;;
  esac
  file="$(profile_file "$name")" || return 1
  parent="$(_toml_string "$file" extends)"
  if [ -n "$parent" ]; then
    _profile_chain "$parent" "$seen $name" || return 1
  fi
  echo "$name"
}

profile_modules() {
  local chain p file m out=""
  chain="$(_profile_chain "$1")" || return 1
  for p in $chain; do
    file="$(profile_file "$p")"
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      case " $out " in *" $m "*) ;; *) out="$out $m" ;; esac
    done <<EOT
$(_toml_list "$file" modules)
EOT
  done
  # shellcheck disable=SC2086
  printf '%s\n' $out
}

profile_has_overlay() {
  local chain p
  chain="$(_profile_chain "$1")" || return 1
  for p in $chain; do
    _toml_bool_true "$(profile_file "$p")" overlay && return 0
  done
  return 1
}

state_dir() { echo "$HOME/.config/dotfiles"; }
remember() {
  mkdir -p "$(state_dir)"
  printf '%s\n' "$2" >"$(state_dir)/$1"
}
recall() { [ -f "$(state_dir)/$1" ] && cat "$(state_dir)/$1"; }
