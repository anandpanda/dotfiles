---
name: sync-secrets
description: User-invocable as /sync-secrets. Pull pantheon secrets from AWS Secrets Manager into the local environment. Use after a fresh clone, when env vars are stale, or when a teammate rotates a secret.
disable-model-invocation: true
---

# /sync-secrets — pantheon secrets refresh

**Cwd gate**: only useful inside `/home/coder/zamp/services/pantheon`. Refuse elsewhere.

## What it does

Wraps `make sync-secrets` (which itself calls `services/pantheon/sync-secrets.sh`). Confirm with `Read` what `sync-secrets.sh` actually does before running — it touches `.env`, `auth.env`, and possibly cert files. The `personal-pre-tool.sh` hook will gate edits to those files (with confirmation).

## Procedure

```bash
cd /home/coder/zamp/services/pantheon

# 1. Confirm AWS auth (the script needs creds)
aws sts get-caller-identity || { echo "AWS auth missing — run \`aws sso login\` or equivalent" >&2; exit 1; }

# 2. Run the project's sync target
make sync-secrets
# (alias: zamp sync_secrets — these may diverge; trust whatever Makefile points at)
```

## What to surface

- The list of secret names that were updated (the script logs these).
- Any secret it tried to fetch but failed on (often a permissions issue).
- The set of files that changed: `git status -- .env auth.env .temporal-cert .temporal-key`.

## Per `factual-mode`

- Don't claim secrets were synced because exit code was 0. Confirm by reading the listed-updated secret names from script output.
- Don't `cat` the secret files into the chat. Their values must not be exfiltrated to the transcript. The auto-allow rule in `~/.claude/settings.json` denies reading sensitive paths anyway, but be explicit: this skill's job is to run the sync, not display contents.

## Side effects to call out

- This rewrites local env files. Any active `make dev` workers may need a restart (`make dev-restart`) to pick up new values.
- If a Temporal cert or key was rotated, you'll need a worker restart for the new TLS to apply.
