#!/usr/bin/env bash
# Engine reachability is a warning: Docker Desktop may simply be closed. Bounded wait.
set -euo pipefail
if command -v docker >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 5 docker info >/dev/null 2>&1 || echo "warn: docker engine not reachable (start Docker Desktop / the docker service)"
  else
    docker info >/dev/null 2>&1 || echo "warn: docker engine not reachable (start Docker Desktop / the docker service)"
  fi
fi
exit 0
