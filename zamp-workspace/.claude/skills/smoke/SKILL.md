---
name: smoke
description: User-invocable as /smoke. Run pantheon's Bruno smoke-test collection against an environment — local, dev, or staging. Use before opening a PR that touches API surface, after a deploy, or to verify endpoints are healthy.
disable-model-invocation: true
---

# /smoke — Bruno smoke tests

**Cwd gate**: meaningful only from `/home/coder/zamp/services/pantheon` (where `pantheon_v2/smoke_tests/collection.bru` lives).

## Usage

```
/smoke [env]
```

`env` is one of the environments defined in the Bruno collection. Default: `local`.

## Procedure

```bash
cd /home/coder/zamp/services/pantheon

# Confirm Bruno CLI is installed
which bru || { echo "bru not installed — see https://www.usebruno.com/" >&2; exit 1; }

# Run the collection
bru run --env "${ENV:-local}" pantheon_v2/smoke_tests/collection.bru
```

## What to surface

- Pass/fail per request, with status codes.
- For any failure: the request name, status, and the response body excerpt.

## Per `factual-mode`

- Don't summarize "all tests pass" without showing the run output.
- If `bru` exits 0 but tests printed warnings, surface them.
- If the chosen env's auth is missing or stale, the failures will be 401/403 — surface that explicitly so the user knows to refresh creds (`make sync-secrets` or whatever the env's flow is) rather than chase phantom bugs.

## Related

- For unit/coverage tests: use `/coverage-diff` (the `coverage-diff` skill).
- For workflow smokes: use `/temporal-test`.
- For end-to-end app smoke: combine `/smoke` + `/temporal-test`.
