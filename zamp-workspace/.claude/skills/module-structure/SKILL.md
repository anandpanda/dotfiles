---
name: module-structure
description: Apply when creating a new module/package in /home/coder/zamp/services/pantheon, or when laying out files for a new feature. Triggers on intents like "new module", "scaffold", "where should this file go", "create platform capability", "create integration".
user-invocable: false
---

# Pantheon Module Layout

**Cwd gate**: only apply when `pwd` is under `/home/coder/zamp/services/pantheon`. Otherwise exit silently.

Authoritative source (read first): `services/pantheon/docs/module_structure_guidelines_v2.md`. The structure below is a quick-reference. When the doc and this skill disagree, the doc wins — and update this skill via `/update-claudemd`.

## The canonical layout

```
pantheon_v2/<layer>/<module_name>/
  workflows/                  # thin (3–5 lines), delegate to service
    __init__.py
    <name>_workflows.py
    tests/test_<name>_workflows.py
  activities/                 # thin (5–10 lines), call service methods
    __init__.py
    <module>_activities.py
    tests/test_<module>_activities.py
  models/<module_name>/       # all domain models for this module
    __init__.py
    <module_name>.py
  services/                   # ALL business logic
    __init__.py
    <module>_service.py
    tests/test_<module>_service.py
  api/
    controllers/
      __init__.py
      <module>_controller.py
      dto/
        requests.py
        responses.py
      tests/test_<module>_controller.py
    router.py                 # FastAPI router
  repository/
    __init__.py
    <module>_store.py
    schemas/                  # SQLAlchemy schemas only
      __init__.py
      <module>.py
  conftest.py                 # shared test fixtures
```

## `<layer>` choices

| Type | `<layer>` | Examples |
|---|---|---|
| Platform capability (LLM, OCR, RAG, sandboxes, repos) | `platform/` | model_orchestrator, credentials_v2, database, ocr |
| External integration (Gmail, S3, Slack, Postgres) | `integrations/` | gmail, slack, s3, postgres |
| HTTP-only surface | `api/` | top-level routers/controllers that fan out |

Reference module to mirror: `pantheon_v2/platform/conversations/` (called out explicitly in the guidelines).

## File naming (no improvisation)

- workflows: `<domain>_workflows.py`
- activities: `<module>_activities.py`
- services: `<module>_service.py`
- repository: `<module>_store.py`
- controllers: `<module>_controller.py`
- tests: `test_<filename>.py`

## What gets tests

Yes: services (most important), controllers, workflows, activities.
No: repositories (thin DB wrappers — test logic in services), schemas.

## Registration steps that trip people up

- New workflow → register in `pantheon_v2/workflows/processes/exposed_workflows.py` (the guidelines call this out — verify the file path before editing).
- New activity → register in the equivalent `exposed_activities.py`.
- If you don't register, the worker won't pick it up.

## Before writing files

1. Read the guidelines doc once.
2. Open `pantheon_v2/platform/conversations/` and skim the actual structure — your new module should look identical in shape.
3. Per `factual-mode`: don't invent a new layout. If you're tempted to deviate, name the deviation and ask.
