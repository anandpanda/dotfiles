# Work Layer Implementation Plan

**Goal:** Context folder lists decide work vs personal everywhere, and any module can add Claude settings through a fragment, so the overlay adds work rules without the public repo knowing company details.

**Spec:** `docs/specs/08-work-layer.md` (public half); the overlay repo's `docs/08-work-layer.md` (private half).

## Global Constraints

- Bash 3.2, `shellcheck -S info`, `shfmt -i 2 -ci`; hermetic bats tests (temp HOME, fakes); never touch the real `~/.claude`, `~/.config/git` or the overlay checkout from tests.
- Public repo: no company names, folder names, profile names or emails (the `tests/claude.bats` company-name test enforces it).
- Overlay checkout is `$(overlay_dir)` (default `~/personal/dotfiles-work`, so it is a personal repo through the normal list); it is fetched before public modules apply (install.sh "configuring" runs after `overlay_ensure`).
- No hooks; no code comments beyond one-line purpose headers; no AI attribution in commits.
- Commits in the public repo use the existing identity; overlay commits use `git -c include.path=$HOME/.config/git/identity.personal` until Task 1 lands.

---

### Task 1: Context folder lists (public)

**Files:** `modules/workspace/contexts/personal`, `modules/workspace/contexts/work`, `lib/contexts.sh`, `modules/git/home/.gitconfig`, `modules/git/install.sh`, `modules/git/doctor.sh`, `modules/gh/shell.zsh`, tests (`tests/contexts.bats`, `tests/git.bats`, `tests/gh.bats`).

**Interfaces:**
- Any module (public or overlay) may ship `contexts/personal` and/or `contexts/work`: one folder per line, `~` allowed, `#` comments and blank lines ignored.
- `contexts_collect` prints `context<TAB>absolute-folder` lines, unique, from every public module in the active profile plus every overlay module under `$(overlay_dir)/modules/*` when the overlay is present.
- Public defaults: personal `~/personal`; work `~/work`. The overlay checkout moves to `~/personal/dotfiles-work`.
- Install writes `~/.config/dotfiles/contexts` (`$(state_dir)`) (the collected lines) and `~/.local/state/git/contexts.inc` with one `[includeIf "gitdir:<folder>/"] path = ~/.config/git/identity.<context>` per line. `.gitconfig` replaces its two hardcoded includeIf blocks with `[include] path = ~/.local/state/git/contexts.inc` (keep `useConfigOnly`).
- The gh context function, commit-hook install and git doctor read the state file instead of hardcoded `~/work`/`~/personal`.

- [x] Tests first: collect merges public + overlay lists and dedups; comments ignored; `~` expanded; generated include has one block per folder; a repo under an overlay-added work folder gets `identity.work` (real `git config user.email` in a temp HOME); a repo under the overlay checkout gets `identity.personal`; gh function picks `work` for an overlay folder; hook install covers an added folder; a folder that does not exist is harmless.
- [x] Implement; `bats tests/contexts.bats tests/git.bats tests/gh.bats tests/workspace.bats`, `just lint`.
- [x] Commit `feat: context folder lists decide work or personal`.

### Task 2: Claude settings fragments (public)

**Files:** `lib/claude.sh`, `modules/claude/install.sh`, `modules/claude/doctor.sh`, `tests/claude.bats`.

**Interfaces:**
- Any module may ship `claude-settings.json`. `claude_settings_expected <owned.json> [fragment.json...]` prints the combined owned settings: `permissions.deny` and `permissions.ask` are concatenated and deduplicated in order; other keys from fragments are deep-merged over owned.
- Install and doctor compute expected from the claude module's owned file plus fragments from every public module in the profile and every overlay module (same discovery as Task 1), then merge or check drift exactly as today.

- [x] Tests first: a fragment's ask rule lands in live settings; a second install keeps it; doctor reports drift when a fragment rule is removed from the live file; no fragment means today's behaviour; duplicates collapse.
- [x] Implement; `bats tests/claude.bats`, `just lint`. Commit `feat(claude): modules add settings through fragments`.

### Task 3: Overlay work layer (private repo)

**Files (overlay):** `modules/claude-work/contexts/work` (the company-named root), `modules/claude-work/home/.claude/rules/work.md` (the four approved rules verbatim from the private spec), `modules/claude-work/claude-settings.json` (prod ask rules), delete `modules/claude-work/home/work/CLAUDE.md`, `modules/claude-work/doctor.sh` (team-skill clash check: names under each work folder's `*/.claude/skills/*` vs `~/.claude/skills/*`), `README.md`.

- [x] Write the files; check the ask rules' syntax against code.claude.com/docs/en/permissions; shellcheck/shfmt the doctor script.
- [x] Commit with the personal identity: `feat: work rules, prod ask rules and work folders for the Claude harness`.

### Task 4: Install, verify, close

- [x] `./install.sh` (remembered profile `work`), `./doctor.sh` clean for the touched modules; remove the stale `~/work/CLAUDE.md` link.
- [x] Verify live: `git config user.email` in a temp repo under each work and personal folder and in the overlay checkout; `jq` shows the prod ask rules in `~/.claude/settings.json`; `~/.claude/rules/work.md` linked; the clash check passes.
- [x] Full `bats tests`, `just lint`; fresh reviewer on both repos; fix; STATUS.
- [ ] Push both repos on Anand's go; CI green.
