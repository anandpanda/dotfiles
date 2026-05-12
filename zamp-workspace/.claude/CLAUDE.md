# Personal Workflow — Anand × Claude

Co-owned working agreement, auto-loaded every session. Lives at `/home/coder/zamp/.claude/CLAUDE.md` (workspace root). Update via `/update-claudemd` (skill W2). Atomic lessons live in `~/.claude/projects/.../memory/` (system-managed); this file captures *how we work together*, not individual facts.

---

## Guiding principles

1. **Be factual, not probabilistic.** No "most likely / possibly / probably / should work / I think" in plans, designs, or code comments. For every non-trivial claim either cite a file path / doc URL / command output, or say "I don't know" and run a verification step (read the file, grep, hit context7 docs MCP, web search). Refuse to implement on an unverified premise. *(Backed by `factual-mode` skill + hookify hedge-word rule.)*
2. **Personal, not company.** This setup lives at workspace level in `/home/coder/zamp/.claude/`. `~/.claude/` is reserved for system-level dotfiles config — leave it alone. Repo-shipped `.claude/` directories (e.g. `services/pantheon/.claude/`) are the company's Pace config; we read them as inspiration only. Disable per repo with `repo-claude off <repo>`.
3. **Industry-standard design.** Default to best practices. When deviating, justify in the PR.
4. **Match scope.** A bug fix doesn't need surrounding cleanup. A one-shot operation doesn't need a helper. Don't design for hypothetical future requirements.

---

## How we work — phase by phase

### 1. Plan
- For any change ≥ ~30 lines or touching multiple files: invoke `superpowers:writing-plans`.
- For exploratory "what could we do" questions: invoke `superpowers:brainstorming` first.
- Plans cite files with `path:line` and reference existing functions to reuse.
- Don't enter plan mode without being asked unless the task is genuinely multi-step.

### 2. Implement
- TDD where it fits: invoke `superpowers:test-driven-development`.
- Bug hunts start with `superpowers:systematic-debugging` — find root cause, don't patch symptoms.
- Long horizons: parallelize independent tasks via `superpowers:dispatching-parallel-agents`.
- Use git worktrees (`superpowers:using-git-worktrees`) when feature work needs isolation.

### 3. Review (before claiming done)
- Always: `superpowers:verification-before-completion` — run the actual verification command and read the output before saying "done".
- Self-review: `code-review:code-review` or `pr-review-toolkit:review-pr`.
- Type-design changes: `pr-review-toolkit:type-design-analyzer`.
- Error-handling changes: `pr-review-toolkit:silent-failure-hunter`.
- Security-sensitive: `security-review`.
- Custom architectural reviewers (cwd-gated to pantheon): `actionshub-reviewer`, `temporal-workflow-reviewer`, `pydantic-boundary-checker`, `cross-module-import-auditor`, `migration-safety-reviewer`.

### 4. PR
- Description format I want **every time** (use `pr-description-writer` agent or `/pr-prep`):
  - **Why** — problem / motivation / linked ticket
  - **How** — approach + key decisions
  - **How verified** — exact commands, test output, screenshots, smoke calls
  - **Summary of what happened** — chronological narrative of the work, including dead-ends
- Never push without explicit permission in the current turn. "Commit" ≠ "push".
- No Claude attribution in commits or PRs (no `Co-Authored-By`, no 🤖 trailers, no "Generated with Claude").

### 5. Retro
- End-of-session: if anything surprising happened, run `/update-claudemd` to propose updates here. Save atomic lessons as auto-memory entries.

---

## Tool routing — when to use what

| Need | Tool / skill |
|---|---|
| Library / SDK / API docs | `mcp__plugin_context7_context7__query-docs` (don't guess from training data) |
| Symbol lookup, find references | `serena` MCP |
| Recurring task on interval | `loop` skill |
| Cron / scheduled remote agent | `schedule` skill |
| Reduce permission prompts | `fewer-permission-prompts` skill |
| Author a hook rule | `hookify:writing-rules` (don't hand-roll settings.json blocks) |
| Audit conversation for hookable patterns | `hookify:conversation-analyzer` |
| Improve a CLAUDE.md | `claude-md-management:claude-md-improver` |
| Create a new skill | `skill-creator:skill-creator` |
| Save session state for resume | `remember:remember` |
| Allowlist hookify rules | `hookify:configure` / `hookify:list` |

---

## Repo-specific behavior

Skills and agents tagged "cwd-gated to pantheon" check `pwd` against `services/pantheon` and exit silently otherwise. Add gates the same way for new repos (`application-platform-frontend`, `windmill-ai-ops`, etc.).

When working inside `services/pantheon`:
- Treat `services/pantheon/.claude.company/` as **read-only inspiration**, never copy from it.
- ActionsHub is non-negotiable; never `from temporalio …` directly. The `actionshub-check` skill loads the full rule set.
- All Pydantic models in `models/models.py`. No raw dicts at activity boundaries.
- 90% coverage; diff-cover ≥75% when ≥30 lines changed.

---

## Anti-patterns I've called out before

- Writing summaries at the end of every response when the diff makes them obvious.
- Adding fallbacks / try-except for things that can't fail.
- Adding comments that restate well-named code.
- Creating `*.md` files I didn't ask for.
- Mocking the database in integration tests.
- Asking for plan approval via plain text instead of `ExitPlanMode`.
- **Defensive error handling / silent fallbacks everywhere.** Only catch errors that are expected AND have a specific product-level recovery action. Don't catch `Exception`, don't swallow with `or {}` / `or None` / `or []` / silent `except`. Code you wrote has known contracts — trust them. If the handler does nothing useful, remove it.
- **Premature infrastructure.** Solve with what already exists first. Only propose new tables, caches, or queues when the simple path is demonstrably insufficient for the actual requirement — not a hypothetical one.
- **Before claiming any batch or feature complete:** restart the server (`make dev-stop && make dev` in `services/pantheon`) and verify response bodies against real endpoints — not just HTTP status codes.
- **Don't implement mid-plan without a checkpoint.** When a non-trivial decision point is reached mid-feature (architecture choice, conflicting approach, ambiguous requirement), stop and surface the options before writing code. Listing A/B/C options in prose and then continuing to work while waiting for an answer is the anti-pattern — use `ExitPlanMode` or pause explicitly. Two hard stops happened in this session because of this.

---

## Maintenance

- This file is the **workflow doc**. Atomic facts go in `~/.claude/projects/.../memory/` (system-managed; don't curate by hand).
- Index of installed plugins: see `~/.claude/plugins/` (system-managed).
- **Our personal config lives at `/home/coder/zamp/.claude/`:**
  - skills: `/home/coder/zamp/.claude/skills/`
  - agents: `/home/coder/zamp/.claude/agents/`
  - commands: `/home/coder/zamp/.claude/commands/`
  - hooks: `/home/coder/zamp/.claude/hooks/` + `/home/coder/zamp/.claude/settings.json`
  - workspace MCPs: `/home/coder/zamp/.mcp.json`
  - hookify rules: `/home/coder/zamp/.claude/hookify.*.local.md`
