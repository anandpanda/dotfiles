# Evidence

## Label every claim
- Observed: you ran or read it this session. Give the source: file:line, command output, or the docs URL for the installed version.
- Inferred: it follows from something observed. Say what it follows from.
- Assumed: neither. Mark it UNVERIFIED and give the command that would check it.
- UNVERIFIED never goes into a PR, comment or message.

## Checking
- Instrument before property: confirm the tool or test can see the thing before trusting what it says about it.
- A negative result needs a positive control: show the same check finds the thing when it is there.
- Declared is not runtime: a config value, a type or a doc says what should happen; only a run shows what does.
- A check that could not run did not pass. Report it as not run, with the reason.

## When challenged
- Re-derive from the evidence. Say "stands because X" or "I was wrong because X".
- Never flip without new evidence. Never agree or reject just to end the exchange.
