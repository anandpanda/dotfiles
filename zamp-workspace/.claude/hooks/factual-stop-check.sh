#!/bin/bash
# F2a — Stop hook: emits a factual-mode self-check reminder before finalizing.
# Uses the additionalContext output to nudge Claude to scan its own response
# for hedge words before stopping.

cat <<'EOF' >&2
[factual-mode] Before finalizing this turn:
  1. Re-scan your last response for hedge words: most likely / probably /
     possibly / should work / I think / appears to / seems to / typically.
     Replace each with evidence (path:line, command output, doc URL) or
     "I don't know — verifying" + an actual verification step.
  2. Confirm every non-trivial claim has a citation.
  3. If you ran a verification command, confirm you READ the output, not
     just that exit code was 0.
  If anything fails, do not finalize — fix it first.
EOF

exit 0
