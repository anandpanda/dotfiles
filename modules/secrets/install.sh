#!/usr/bin/env bash
# ~/.secrets (700), an age key (600, generated once), a .sops.yaml that encrypts to it.
set -euo pipefail
for f in log secrets; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
d="$(secrets_dir)"; key="$(secrets_age_key)"; cfg="$d/.sops.yaml"
if [ -d "$d" ]; then
  echo "skip $d"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] mkdir $d (mode 700)"
else
  mkdir -p "$d" && chmod 700 "$d" && echo "mkdir $d"
fi
if ! command -v age-keygen >/dev/null 2>&1; then
  log_warn "age not installed yet (brew bundle installs it); the key is generated on the next run"
elif [ -f "$key" ]; then
  echo "skip $key"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] age-keygen -o $key"
else
  (umask 077 && age-keygen -o "$key" 2>/dev/null)
  chmod 600 "$key"
  echo "generated $key: the one secret that opens the rest, back it up in your password manager"
fi
if [ -f "$key" ] && command -v age-keygen >/dev/null 2>&1; then
  pub="$(age-keygen -y "$key")"
  want="$(printf 'creation_rules:\n  - path_regex: .*\n    age: %s\n' "$pub")"
  if [ -f "$cfg" ] && [ "$(cat "$cfg")" = "$want" ]; then
    echo "skip $cfg"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] write $cfg"
  else
    printf '%s\n' "$want" >"$cfg" && echo "wrote $cfg (encrypts to your age key)"
  fi
fi
missing="$(secrets_missing)"
if [ -n "$missing" ]; then
  echo "missing secrets (add with: sops $(secrets_file)):"
  while IFS= read -r line; do echo "  $line"; done <<<"$missing"
fi
