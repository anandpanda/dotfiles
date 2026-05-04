---
name: actionshub-check
description: Apply when working in /home/coder/zamp/services/pantheon — loads the non-negotiable ActionsHub rules and architectural invariants. Triggers when implementing/reviewing/discussing pantheon workflows, activities, controllers, services, or any code under pantheon_v2/.
user-invocable: false
---

# ActionsHub Non-Negotiables — Pantheon

**Cwd gate**: only apply when `pwd` is under `/home/coder/zamp/services/pantheon`. Otherwise exit silently.

Source of truth: `services/pantheon/docs/module_structure_guidelines_v2.md` (currently open in IDE for the user).

## Call flow (memorize)

```
HTTP Request → Router → Controller → ActionsHub.execute_activity() → Activity → Service
                                  ↑                                           ↓
                                  └───────────── NEVER SKIP ─────────────────┘
```

Reference: `services/pantheon/CLAUDE.md` (currently `.claude.company` since `repo-claude off`; can be re-enabled with `repo-claude on /home/coder/zamp/services/pantheon`).

## Rules — these are not suggestions

1. **Always go through ActionsHub.** `from temporalio …` is forbidden in application code. Workflows and activities are exposed via `ActionsHub.execute_activity` / `execute_workflow`.
2. **Controllers call activities, never services directly.** A controller importing from `<module>/services/` is a bug. Use `ActionsHub.execute_activity(...)`.
3. **Cross-module communication = call the other module's activity.** Never `from pantheon_v2.<other_module>.services...`. Use `ActionsHub.execute_activity` with `ExecutionMode.INLINE` for in-process calls.
4. **Workflows and activities are thin wrappers** (5–10 lines). All business logic lives in services.
5. **Pydantic everywhere.** No raw `dict` for activity inputs/outputs. Single Pydantic input object, object return type — never primitives.
6. **Models live in the module's `models/` directory** per `module_structure_guidelines_v2.md` (specifically `<module_name>/models/<module_name>/<module_name>.py`). The older root CLAUDE.md says `models.py` — verify per-module which convention the codebase actually uses before deciding.
7. **Absolute imports only.** No `from .` or `from ..`.
8. **No magic strings or numbers** — promote to constants.
9. **90% coverage overall, diff-cover ≥75%** when ≥30 lines changed (see `services/pantheon/tests.sh`).

## Self-check greps before declaring done

Run these from `services/pantheon/` and confirm no hits in your changes:

```bash
# Direct temporalio imports outside ActionsHub
git diff main -- 'pantheon_v2/**/*.py' | grep -E '^\+.*\b(from temporalio|import temporalio)\b'

# Relative imports
git diff main -- 'pantheon_v2/**/*.py' | grep -E '^\+\s*from\s+\.\.?'

# Controller importing services
git diff main -- 'pantheon_v2/**/controllers/**/*.py' \
  | grep -E '^\+.*\bfrom pantheon_v2\..+\.services\b'

# Cross-module service imports (module A importing module B's services)
# Manual review needed — this catches the obvious case but module B is anything ≠ A.
```

## What to do when uncertain

Per `factual-mode`: don't guess. If the codebase already does X a particular way, find the canonical example and cite it. Likely canonical references:

- Reference module: `pantheon_v2/platform/conversations/` (named in the guidelines as the structural template)
- Reference platform module: `pantheon_v2/platform/skills/`
- Activity registration: search for `@ActionsHub.register_activity` in the codebase
- Cross-module call pattern: search for `ExecutionMode.INLINE`

Read those before writing new code in the same shape.
