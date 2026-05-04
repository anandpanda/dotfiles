#!/usr/bin/env bash
# Install workspace MCPs by sourcing pantheon's .env at runtime.
# This script does NOT contain secrets — they are read from .env when you run it.
#
# Usage:
#   /home/coder/zamp/.claude/setup-mcps.sh [github|postgres|temporal|grafana|all]
#
# Default: all (skip those whose required vars are missing).

set -euo pipefail

WORKSPACE_ROOT="/home/coder/zamp"
ENV_FILE="$WORKSPACE_ROOT/services/pantheon/.env"
TARGET="${1:-all}"

# Always install into the workspace's .mcp.json regardless of cwd
cd "$WORKSPACE_ROOT"

# --- Read individual keys from .env without sourcing (some values contain
# --- shell-special characters that break `set -a; . file; set +a`). ---
read_env() {
    local key="$1"
    [ -f "$ENV_FILE" ] || return 1
    # Match KEY=value, strip optional surrounding quotes, return raw value.
    sed -nE "s/^${key}=['\"]?([^'\"]*)['\"]?\$/\1/p" "$ENV_FILE" | head -1
}

want() {
    [ "$TARGET" = "all" ] || [ "$TARGET" = "$1" ]
}

# Helper: run claude mcp add but never log the resolved env values
mcp_add() {
    local name="$1"; shift
    echo "Installing MCP: $name"
    claude mcp add --scope project "$name" "$@"
}

# ---- M3: GitHub (remote HTTP, OAuth on first use, NO secret needed) ----
if want github; then
    claude mcp add --scope project --transport http github https://api.githubcopilot.com/mcp/ \
        || echo "github install failed — already added? rerun with: claude mcp remove --scope project github"
fi

# ---- M2: Postgres (read-only, dev DSN from PLATFORM_POSTGRES_DSN) ----
if want postgres; then
    pg_dsn="$(read_env PLATFORM_POSTGRES_DSN)"
    if [ -n "$pg_dsn" ]; then
        mcp_add postgres \
            -e DATABASE_URL="$pg_dsn" \
            -- npx -y @henkey/postgres-mcp-server \
            || echo "postgres install failed"
    else
        echo "skip postgres: PLATFORM_POSTGRES_DSN not set in $ENV_FILE" >&2
    fi
fi

# ---- M7: Temporal — resolve via pantheon Settings (Config Store) ----
# This connects to whichever Temporal env pantheon itself uses (dev Cloud for Coder).
if want temporal; then
    pantheon_dir="/home/coder/zamp/services/pantheon"
    # Fetch host/namespace by asking pantheon's own Settings (same mechanism temporal-cli uses).
    # Use a unique prefix so we can grep past the structlog noise that may go to stdout.
    temporal_resolved=$(cd "$pantheon_dir" && poetry run python -c "
import os
os.environ.setdefault('ENVIRONMENT', 'coder')
os.environ.setdefault('REGION', 'mum')
import pantheon_v2.platform.observability  # loads .env, configures logging
from pantheon_v2.settings.settings import Settings
print(f'__MCPRESOLVE__|{Settings.TEMPORAL_HOST}|{Settings.TEMPORAL_NAMESPACE}|{int(Settings.is_cloud())}')
" 2>/dev/null | grep '^__MCPRESOLVE__|' | head -1)
    # Strip the marker prefix and split
    temporal_resolved="${temporal_resolved#__MCPRESOLVE__|}"
    IFS='|' read -r T_HOST T_NS T_CLOUD <<< "$temporal_resolved"
    if [ -z "$T_HOST" ]; then
        echo "skip temporal: failed to resolve TEMPORAL_HOST from Settings — run \`cd $pantheon_dir && poetry install\` first?" >&2
    else
        # Build install command. For Temporal Cloud, attach mTLS cert/key.
        cert_args=()
        if [ "$T_CLOUD" = "1" ] && [ -f "$pantheon_dir/.temporal-cert" ] && [ -f "$pantheon_dir/.temporal-key" ]; then
            cert_args=(
                -e "TEMPORAL_TLS_CERT_PATH=$pantheon_dir/.temporal-cert"
                -e "TEMPORAL_TLS_KEY_PATH=$pantheon_dir/.temporal-key"
            )
        fi
        echo "  → resolved TEMPORAL_HOST=$T_HOST namespace=$T_NS cloud=$T_CLOUD"
        mcp_add temporal \
            -e "TEMPORAL_ADDRESS=$T_HOST" \
            -e "TEMPORAL_NAMESPACE=$T_NS" \
            "${cert_args[@]}" \
            -- npx -y temporal-mcp \
            || echo "temporal install failed — run \`npx -y temporal-mcp --help\` to verify the env-var names. The package is young (0.2.1); they may have changed."
    fi
fi

# ---- M12: Grafana ----
# Pantheon's Config Store does NOT contain a GRAFANA URL. Two options:
#   1. Local obs_stack: http://localhost:3001 (anonymous Admin per zamp_dev_setup/obs_stack/docker-compose.yaml).
#   2. Shared dev Grafana: provide GRAFANA_URL + GRAFANA_SERVICE_ACCOUNT_TOKEN in your shell.
if want grafana; then
    if [ -n "${GRAFANA_URL:-}" ]; then
        env_args=(-e "GRAFANA_URL=$GRAFANA_URL")
        if [ -n "${GRAFANA_SERVICE_ACCOUNT_TOKEN:-}" ]; then
            env_args+=(-e "GRAFANA_SERVICE_ACCOUNT_TOKEN=$GRAFANA_SERVICE_ACCOUNT_TOKEN")
        fi
        mcp_add grafana "${env_args[@]}" -- npx -y mcp-grafana-npx \
            || echo "grafana install failed — verify env-var names with \`npx -y mcp-grafana-npx --help\`"
    else
        cat >&2 <<EOF
skip grafana: GRAFANA_URL not set. Pick one:
  - Local stack (anonymous):
      docker compose -f /home/coder/zamp/zamp_dev_setup/obs_stack/docker-compose.yaml up -d
      export GRAFANA_URL=http://localhost:3001
      $0 grafana
  - Shared dev Grafana:
      export GRAFANA_URL=https://<your-dev-grafana-url>
      export GRAFANA_SERVICE_ACCOUNT_TOKEN=<service-account-token>
      $0 grafana
EOF
    fi
fi

echo
echo "Done. Verify:"
echo "  claude mcp list | grep -E '^(github|postgres|temporal|grafana)'"
