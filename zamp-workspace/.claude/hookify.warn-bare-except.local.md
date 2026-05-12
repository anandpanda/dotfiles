---
name: warn-bare-except
enabled: true
event: file
pattern: except\s+(Exception|BaseException)\s*:
action: warn
---

Bare `except Exception` / `except BaseException` detected.

Only catch if there is a concrete, observed failure mode that catching actually handles. Let errors propagate — don't swallow them defensively.
