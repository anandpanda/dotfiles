---
name: warn-defensive-error-handling
enabled: true
event: file
pattern: except\s+Exception|except\s*:\s*$|or\s+\{\}|or\s+\[\]|or\s+None\b|or\s+0\b|or\s+False\b|or\s+True\b|or\s+""
---

**Defensive error handling detected.**

Rule: Only catch errors that are **expected AND have a specific product-level recovery action**.

- If you know a function throws X in a real scenario, and your code can meaningfully handle it (retry, fallback, user-facing message) — catch it.
- Otherwise, **let it propagate**. Don't catch "just in case."
- Don't swallow with empty fallbacks (`or {}`, `or None`, `or []`, silent `except`).
- Don't add `try/except` around code you wrote — you know its contracts. Trust them.

The instinct to over-handle comes from treating code as unpredictable. But you wrote it. You know its invariants. Minimal handling only.

Ask yourself: "What specific failure am I handling here, and what does my code actually do with it?"
If the answer is "nothing" or "I'm not sure" — remove the handler.
