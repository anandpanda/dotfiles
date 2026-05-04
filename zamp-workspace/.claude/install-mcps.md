# MCP install commands — run these yourself

Each command takes a secret. Run them in your shell (or via `! <command>` from chat) so secrets don't land in Claude's transcript. All install at **project scope** (writes to `/home/coder/zamp/.mcp.json`).

---

## M3 — GitHub (remote HTTP, OAuth on first use)

```bash
claude mcp add --scope project --transport http github https://api.githubcopilot.com/mcp/
```

Source: [github/github-mcp-server](https://github.com/github/github-mcp-server). The npm package `@modelcontextprotocol/server-github` is deprecated; do not use it.

---

## M2 — Postgres (read-only, dev DSN only)

```bash
export DEV_DATABASE_URL='postgres://user:pass@host:5432/db?sslmode=require'

claude mcp add --scope project postgres \
  -e DATABASE_URL="$DEV_DATABASE_URL" \
  -- npx -y @henkey/postgres-mcp-server
```

Use `@henkey/postgres-mcp-server@1.0.5` (maintained). The official `@modelcontextprotocol/server-postgres` is deprecated. Never wire a prod DSN to a Claude MCP.

---

## M7 — Temporal (read-only inspector)

```bash
claude mcp add --scope project temporal -- npx -y temporal-mcp
```

If `temporal-mcp` needs explicit connection env vars (likely for Temporal Cloud), set them before the install command:

```bash
export TEMPORAL_ADDRESS='<host:port>'        # e.g. localhost:7233 for local dev
export TEMPORAL_NAMESPACE='<namespace>'      # if not 'default'
# For Temporal Cloud TLS, additionally:
# export TEMPORAL_TLS_CERT="$(cat path/to/cert.pem)"
# export TEMPORAL_TLS_KEY="$(cat path/to/key.pem)"

claude mcp add --scope project temporal \
  -e TEMPORAL_ADDRESS="$TEMPORAL_ADDRESS" \
  -e TEMPORAL_NAMESPACE="$TEMPORAL_NAMESPACE" \
  -- npx -y temporal-mcp
```

Run `npx -y temporal-mcp --help` first to confirm the exact env var names — `temporal-mcp@0.2.1` is young and the surface may move.

---

## M12 — Grafana

```bash
export GRAFANA_URL='https://<your-grafana-host>'
export GRAFANA_SERVICE_ACCOUNT_TOKEN='<service-account-token>'

claude mcp add --scope project grafana \
  -e GRAFANA_URL="$GRAFANA_URL" \
  -e GRAFANA_SERVICE_ACCOUNT_TOKEN="$GRAFANA_SERVICE_ACCOUNT_TOKEN" \
  -- npx -y mcp-grafana-npx
```

`mcp-grafana-npx` is an npm wrapper around the official Go binary `grafana/mcp-grafana@v0.13.1`. Use a Grafana **service account** token, not a personal API key. If the env var name doesn't match, check `npx -y mcp-grafana-npx --help` for the right one.

---

## After each install — verify

```bash
claude mcp list | grep -E '^(github|postgres|temporal|grafana)'
```

Every line should show `✓ Connected`. If one shows `✗ Failed`:

```bash
# Re-launch Claude with debug to see MCP startup errors
claude --mcp-debug
```

## Roll back any MCP

```bash
claude mcp remove --scope project <name>
```

---

## Source citations

- GitHub MCP modern endpoint: github/github-mcp-server README, current main branch.
- npm deprecations: `npm view @modelcontextprotocol/server-github` and `… server-postgres` both report `DEPRECATED ⚠️`.
- `@henkey/postgres-mcp-server`: latest 1.0.5 on npm at time of writing (2026-05-04).
- `temporal-mcp`: latest 0.2.1 on npm at time of writing (2026-05-04).
- `mcp-grafana-npx`: latest 1.0.1 on npm; wraps grafana/mcp-grafana@v0.13.1.

When you install a new MCP, update this file with the actual env-var names you used (the placeholders above are best-effort defaults). Run `/update-claudemd` after to fold any lessons into `CLAUDE.md`.
