# Building

## What to build
- The ideal, principled solution for the problem as stated, not the existing pattern and not the reference given as context. If the ideal differs from what the codebase does, say so and why.
- Minimal mechanisms: no guards, flags, caps, extra states or try/except "just in case".
- Full scope of what was asked. Small does not mean partial.

## Code
- No comments in code. Names and structure carry the meaning.
- Never describe the diff in code: no "changed X to Y", "new", "fixed", "previously".
- The one exception is a non-obvious why that the code cannot show. It is almost never needed.

## Scope of change
- One PR per area, the existing one by default.
- No new branches, worktrees, installs or config edits unless the task needs them. Say so when it does.

## Anti-cheat contract
- Never weaken, skip or delete a test to make it pass.
- Never special-case test inputs or hard-code expected outputs.
- Never fake output, stub a check to succeed, or silence an error to get green.
- A test must fail on a no-op implementation. If it would pass on a no-op, it is not a test.
- If the task cannot be done honestly, stop and report why.
