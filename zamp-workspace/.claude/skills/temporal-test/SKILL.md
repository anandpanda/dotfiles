---
name: temporal-test
description: User-invocable as /temporal-test. Run a pantheon Temporal workflow end-to-end after code changes — restart workers, dispatch the workflow, poll status, surface failures. Args — workflow class name and JSON input. Use after any change to a workflow or activity in services/pantheon.
disable-model-invocation: true
---

# /temporal-test — workflow smoke run

**Cwd gate**: only meaningful inside `/home/coder/zamp/services/pantheon`. Refuse to run elsewhere.

The pantheon root `CLAUDE.md` (and our workflow doc) require running this dance after any workflow/activity change. This skill packages it.

## Usage

```
/temporal-test <WorkflowClass> '<json-input>'
```

Example:

```
/temporal-test InvoiceProcessingWorkflow '{"invoice_id":"abc-123"}'
```

## Procedure

```bash
cd /home/coder/zamp/services/pantheon

# 1. Confirm services are up. If not, start them.
make dev-status
# If anything is missing:
make dev    # or `make dev-hot` for hot-reload during iterative changes

# 2. Restart workers so they pick up the new code.
make dev-restart

# 3. Dispatch the workflow.
poetry run temporal-cli run "$WORKFLOW_CLASS" --input "$INPUT_JSON"
# Capture the run_id from the output — it's needed for step 4.

# 4. Poll status until terminal.
poetry run temporal-cli status "$RUN_ID" --pretty
# Re-run periodically; or wait for completion if the CLI supports `--wait`.
```

## What to surface to the user

- Run ID, workflow status (Completed / Failed / TimedOut / Continued).
- For failures: paste the exception type + message + the relevant 5–10 lines of stack trace. Do not paraphrase — copy the actual output.
- For success: paste the workflow output payload (the activity return).

## Failure recovery

- If `make dev-restart` fails (workers don't come up): run `make dev-status`, then `make dev-logs` (or `make dev-tail` while reproducing). Don't paper over startup failures.
- If the workflow fails mid-run with `RetryableError`: confirm the underlying transient is real (check the activity's logs) before declaring the workflow itself broken.
- If `temporal-cli run` errors with "workflow not found": the new workflow isn't registered. Verify it's added to `pantheon_v2/workflows/processes/exposed_workflows.py` (per `module-structure` skill).

## Per `factual-mode`

Don't claim "the workflow runs" because the dispatch returned exit 0. Read the actual status output. A workflow can dispatch successfully and then fail asynchronously — the **status check is the verification**, not the dispatch.

## When to skip

- Pure documentation or test-only changes that don't touch workflow/activity code → skip; just run unit tests.
- Activity-only change that doesn't change the activity's signature → unit tests + `bru run` smoke may be sufficient. Use judgment.
