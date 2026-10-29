#!/usr/bin/env bash
# ~/.secrets (700), an age key (600, generated once), and its public half in age.pub
# (the shell exports it as SOPS_AGE_RECIPIENTS, so sops encrypts to it from any directory).
set -euo pipefail
for f in log secrets; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
d="$(secrets_dir)"; key="$(secrets_age_key)"; pub="$d/age.pub"
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
  want="$(age-keygen -y "$key")"
  if [ -f "$pub" ] && [ "$(cat "$pub")" = "$want" ]; then
    echo "skip $pub"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] write $pub"
  else
    printf '%s\n' "$want" >"$pub" && echo "wrote $pub (sops encrypts to it)"
  fi
fi
missing="$(secrets_missing)"
if [ -n "$missing" ]; then
  echo "missing secrets (add with: sops $(secrets_file)):"
  while IFS= read -r line; do echo "  $line"; done <<<"$missing"
fi
