---
name: cross-module-call
description: Apply when code in one pantheon module needs functionality from another module. Triggers when you see imports across modules, when planning a call from module A's service to module B, when the user asks "how do I call X from Y", or when reviewing diffs that import another module's services.
user-invocable: false
---

# Cross-Module Communication — Pantheon

**Cwd gate**: only apply when `pwd` is under `/home/coder/zamp/services/pantheon`. Otherwise exit silently.

## The rule (one sentence)

Module A's service calls **module B's activity** through `ActionsHub.execute_activity` — never `from pantheon_v2.<other_module>.services...`.

## Why

- Decouples modules: B can change its internal service signature without breaking A.
- Same code path runs both inside Temporal workflows and inline calls — `ExecutionMode.INLINE` is the switch.
- Observability: every cross-module call shows up in ActionsHub telemetry.

## The pattern (canonical)

```python
from datetime import timedelta
from zamp_public_workflow_sdk.actions_hub import ActionsHub, ExecutionMode
from pantheon_v2.platform.sandbox.activities import sandbox_exec
from pantheon_v2.platform.sandbox.models import SandboxExecInput, SandboxExecOutput

class FileSystemService:
    async def _exec(self, org_id: str, command: str) -> SandboxExecOutput:
        return await ActionsHub.execute_activity(
            sandbox_exec,
            SandboxExecInput(org_id=org_id, command=command),
            return_type=SandboxExecOutput,
            start_to_close_timeout=timedelta(minutes=5),
            execution_mode=ExecutionMode.INLINE,
        )
```

Citation for this pattern: previously documented in `services/pantheon/CLAUDE.md` (now `.claude.company/CLAUDE.md` after `repo-claude off`). Verify against the live `pantheon_v2/platform/orchestrator/actions/README.md` before relying on signatures.

## ExecutionMode quick guide

- `ExecutionMode.INLINE` — runs as a normal `await` (no Temporal queue). Use for in-process service-to-service calls.
- Default (no mode) — full Temporal activity execution. Use from inside workflows.

Read `services/pantheon/docs/module_structure_guidelines_v2.md` → "ExecutionMode Guidelines" section before deciding.

## Anti-patterns to flag

```python
# ❌ Direct service import across modules
from pantheon_v2.platform.users.services.user_service import UserService

# ❌ Reaching into another module's repository
from pantheon_v2.platform.users.repository.users_store import UsersStore

# ❌ Importing another module's models from a module-private location
# (use shared models if they exist in pantheon_v2/platform/common/models/)
```

If you see any of the above being added, stop and rewrite as an `ActionsHub.execute_activity` call to the target module's exposed activity. If the activity doesn't exist yet, the right move is usually to add one to the target module — not bypass the rule.

## Self-check before submitting

```bash
git diff main -- 'pantheon_v2/**/*.py' \
  | grep -E '^\+.*\bfrom pantheon_v2\.[^.]+\.(services|repository)\b' \
  | grep -v '^\+.*\bfrom pantheon_v2\.SAME_MODULE\.'
```

(replace `SAME_MODULE` with the module you're editing — the grep should show zero results across modules).
