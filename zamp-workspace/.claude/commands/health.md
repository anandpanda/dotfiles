---
description: Show pantheon dev-environment health — services running, ports up, workers connected.
---

Run `make health` from `/home/coder/zamp/services/pantheon` and surface the result. If anything is unhealthy, list the specific failed checks and propose the targeted fix (start the missing service, free a port, restart workers) — don't propose a full `make dev-clean` unless the user asks.

Per `factual-mode`: read the actual `make health` output. Don't claim "looks healthy" because the command exited 0 — some Makefile health targets exit 0 even when individual checks warn.
