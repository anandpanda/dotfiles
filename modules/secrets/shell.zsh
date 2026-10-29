# sops: the age key that decrypts, and the recipient new files are encrypted to (any cwd).
export SOPS_AGE_KEY_FILE="$HOME/.secrets/age.key"
[[ -r "$HOME/.secrets/age.pub" ]] && export SOPS_AGE_RECIPIENTS="$(<"$HOME/.secrets/age.pub")"
# with-secrets <cmd...>: run a command with every secret as an env var; values never hit the terminal.
with-secrets() { sops exec-env "$HOME/.secrets/secrets.yaml" "$*"; }
