# sops finds the age key here; `sops ~/.secrets/secrets.yaml` edits, `sops exec-env` runs with secrets.
export SOPS_AGE_KEY_FILE="$HOME/.secrets/age.key"
# with-secrets <cmd...>: run a command with every secret as an env var; values never hit the terminal.
with-secrets() { sops exec-env "$HOME/.secrets/secrets.yaml" "$*"; }
