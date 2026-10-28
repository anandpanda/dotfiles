#!/usr/bin/env bash
# Engine reachability is a warning: Docker Desktop may simply be closed.
set -euo pipefail
if command -v docker >/dev/null 2>&1; then
  docker info >/dev/null 2>&1 || echo "warn: docker engine not reachable (start Docker Desktop / the docker service)"
fi
exit 0
