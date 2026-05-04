---
name: pydantic-models-rule
description: Apply when defining data shapes in pantheon — activity I/O, workflow I/O, API request/response, service contracts. Triggers when adding a Pydantic class, a dataclass, a TypedDict, or any new structured type.
user-invocable: false
---

# Pydantic-Only Discipline — Pantheon

**Cwd gate**: only apply when `pwd` is under `/home/coder/zamp/services/pantheon`. Otherwise exit silently.

## The rule

All structured data types are **Pydantic `BaseModel` subclasses**. No `dataclass`, no `TypedDict`, no raw `dict`.

## Where models live

Two source-of-truth docs disagree:

| Doc | Says |
|---|---|
| `services/pantheon/docs/module_structure_guidelines_v2.md` | Per-module: `<module>/models/<module_name>/<module_name>.py` |
| `services/pantheon/CLAUDE.md` (now `.claude.company/CLAUDE.md`) | All Pydantic models in `models.py` |

**Per `factual-mode`: don't pick a side from this skill alone.** Open the module you're editing, look at where its existing models live, and follow the local convention. If the module is new, follow `module_structure_guidelines_v2.md` (the v2 doc is newer; the older root rule may be stale). When unsure, ask.

## What's mandatory regardless of location

- `BaseModel` subclass with `Field(description=...)` on every field.
- `@external` decorator on models exposed via ActionsHub or to customers — see `from zamp_public_workflow_sdk.actions_hub.models.decorators import external`.
- Activities take **one** Pydantic input and return **one** Pydantic output (or a Pydantic-wrapped collection). Never primitives directly.

## Anti-patterns

```python
# ❌ Raw dict at activity boundary
async def my_activity(input: dict) -> dict: ...

# ❌ Returning a primitive
async def get_count(input: QueryInput) -> int: ...

# ❌ TypedDict / dataclass
@dataclass
class FooInput: ...

class BarOutput(TypedDict): ...

# ❌ Models defined inside an activities or workflow file
# (move them to the module's models directory)
@ActionsHub.register_activity("...")
async def handle(req: BaseModel) -> BaseModel:
    class InlineModel(BaseModel): ...   # WRONG — extract to models/
```

## The correct shape

```python
# pantheon_v2/<layer>/<module>/models/<module>/<module>.py
from pydantic import BaseModel, Field
from zamp_public_workflow_sdk.actions_hub.models.decorators import external

@external
class FooInput(BaseModel):
    """Input for foo_activity."""
    org_id: str = Field(description="Organization identifier (UUID)")
    target: str = Field(description="What we're acting on")

@external
class FooOutput(BaseModel):
    """Output from foo_activity."""
    result: str = Field(description="Outcome of the action")
    count: int = Field(description="Items processed")
```

## Self-check

```bash
# Activity functions whose annotations include "dict"
git diff main -- 'pantheon_v2/**/activities/**/*.py' \
  | grep -E '^\+.*async def .*(\bdict\b|\bDict\[)' || echo "OK"

# dataclass decorator anywhere in pantheon_v2 source
git diff main -- 'pantheon_v2/**/*.py' \
  | grep -E '^\+@dataclass' || echo "OK"
```

If anything other than `OK` shows, fix before declaring done.
