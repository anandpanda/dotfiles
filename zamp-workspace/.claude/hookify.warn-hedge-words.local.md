---
name: warn-hedge-words
enabled: true
event: all
pattern: \b(most likely|probably|possibly|presumably|should work|should be able to|I think|I believe|I assume|I'd guess|typically|usually|in most cases|appears to|seems to|I suspect)\b
---

**Unverified claim detected.** You used a hedge word in your response.

You have two options:
1. **Find the evidence** — Read the file, run `grep`, execute the command, or check the docs before stating the claim.
2. **Say "I don't know — verifying"** — then go verify.

Do NOT emit probabilistic claims about code behaviour. The `factual-mode` rule applies: no "likely/probably/should work" without a citation (file path + line number, command output, or doc URL).
