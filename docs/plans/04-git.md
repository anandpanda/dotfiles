# Git Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modern git defaults, delta diffs, SSH signing per identity with local verification, a Conventional Commits hook, lazygit, `gh` with two accounts switching by directory, and worktree helpers.

**Architecture:** The Phase 1 `git` module grows (gitconfig, identity signing keys, hooks dir, allowed_signers generator, doctor). Two new modules: `lazygit` (config under `home/` because its dir is per-OS... no: lazygit honours `~/.config/lazygit` on both OSes when `XDG_CONFIG_HOME`/`~/.config` exists, so `config/` works), `gh` (aliases via CLI, chpwd account switch, preflight login). All tests run against a temp HOME with fake `gh` where needed.

**Tech Stack:** git 2.51, delta 0.19, difftastic, lazygit 0.62, gh 2.93, bats.

**Spec:** `docs/specs/04-git.md`

## Global Constraints

- All earlier constraints. Signing tests generate a throwaway ed25519 key in the temp HOME; never touch real keys.
- No account names or emails other than the personal one in the public repo; work account name is remembered per machine.

## Review Focus

1. commit-msg hook with a multi-line message whose first line is valid: accepts (Task 1 test).
2. `allowed_signers` when the work key is absent: only the personal line, no empty line (Task 1 test).
3. chpwd hook when `gh` is not installed or the account files are missing: silent no-op, never an error on every `cd` (Task 3 test).
4. `git pushf` must be `--force-with-lease`, never `--force` (Task 1 test greps the alias).
5. lazygit config dir on macOS: lazygit uses `~/Library/Application Support/lazygit` unless `~/.config/lazygit/config.yml` exists; the module must put it where lazygit reads it (Task 2 test runs `lazygit --print-config-dir` with HOME set, if installed).

---

### Task 1: git module: config, signing, hook, allowed_signers, doctor, shell helpers

**Files:** modify `modules/git/home/.gitconfig`, `modules/git/config/identity.personal`; create `modules/git/config/hooks/commit-msg`, `modules/git/install.sh`, `modules/git/doctor.sh`, `modules/git/shell.zsh`, `modules/git/Brewfile`, `modules/git/CHECKLIST.md`; update `modules/git/README.md`, `overlays/work.example/modules/git/config/identity.work`; tests in `tests/git.bats`.

- [ ] Tests (RED): gitconfig parses and has the key settings; every alias resolves (`git config --get alias.X` non-empty for the list); `pushf` contains `force-with-lease`; hook accepts `feat: x`, `fix(api)!: y`, `Merge branch 'x'`, `fixup! feat: x`, `Revert "feat: x"`, multi-line with valid first line; rejects `update stuff`, `Feat: x`, empty; `install.sh` writes allowed_signers with one key, two keys, no blank lines, rerun identical, dry run writes nothing; signed commit in a temp `~/personal/r` with a generated key verifies (`git log --show-signature` contains "Good"); `doctor.sh` reports a missing signing key; `shell.zsh` parses and `gwt` creates a sibling worktree.
- [ ] Implement:
  - `.gitconfig`: the settings in the spec, `[core] pager = delta`, `hooksPath = ~/.config/git/hooks`, `[interactive] diffFilter = delta --color-only`, `[delta] navigate, line-numbers, side-by-side, syntax-theme "Catppuccin Mocha"` plus `[include] path = ~/.config/git/catppuccin.gitconfig` (vendored from catppuccin/delta, `features = catppuccin-mocha`), `[gpg] format = ssh`, `[gpg "ssh"] allowedSignersFile = ~/.config/git/allowed_signers`, `[commit] gpgsign = true`, `[tag] gpgsign = true`, `[difftool "difftastic"] cmd = difft "$LOCAL" "$REMOTE"`, `[difftool] prompt = false`, aliases.
  - `identity.personal`: `signingkey = ~/.ssh/id_ed25519_personal.pub`. Example overlay identity gets `id_ed25519_work.pub`.
  - `hooks/commit-msg` (bash, executable): read first non-comment line; allow merge/revert/fixup/squash; regex check; on failure print the rule and exit 1.
  - `install.sh`: build `~/.config/git/allowed_signers` from `(email, pubkey)` pairs: personal email from `identity.personal`, work email from `identity.work` if present; include a line only when the pubkey file exists; write atomically only if content differs; dry run prints.
  - `doctor.sh`: for each identity file present, the signingkey file exists; allowed_signers matches what install would write; hooks dir linked.
  - `shell.zsh`: `gwt`, `gwtl`, `gwtr`, `alias lg=lazygit`.
  - `Brewfile`: git, git-delta, difftastic. `CHECKLIST.md`: register each `.pub` as a Signing key on GitHub.
- [ ] GREEN, lint, commit `feat(git): modern defaults, delta, ssh signing with local verification, commit-msg hook, worktree helpers`.

### Task 2: lazygit module

**Files:** `modules/lazygit/{Brewfile,config/config.yml,install.sh,README.md}`, `tests/lazygit.bats`.

- [ ] Tests: config links; YAML parses (python3 yaml if available else skip); on macOS `install.sh` also links `~/Library/Application Support/lazygit/config.yml` to the same file (lazygit's macOS default) and the test checks it; `lazygit --print-config-dir` with the temp HOME points at a dir containing our config when lazygit is installed.
- [ ] Implement: Catppuccin Mocha theme block (vendored from catppuccin/lazygit mocha/blue.yml), `git.paging.pager: delta --dark --paging=never`, `gui.nerdFontsVersion: "3"`, `gui.showIcons`, `os.editPreset: vscode`, `git.autoFetch`, `update.method: never`; README with the ten keys.
- [ ] Commit `feat: lazygit module`.

### Task 3: gh module

**Files:** `modules/gh/{Brewfile,install.sh,preflight.sh,shell.zsh,README.md}`, `tests/gh.bats`.

- [ ] Tests (fake `gh` logging calls; `auth status` output driven by a file): `install.sh` sets each alias once (second run makes no `alias set` calls); `preflight.sh` without tty prints login commands and exits 0; with DOTFILES_TTY and a fake `gh auth login` it remembers the username into `~/.config/dotfiles/gh_personal`; `shell.zsh` parses; the chpwd function switches to the right account when crossing roots and is a no-op without gh or without the files; never errors.
- [ ] Implement:
  - `install.sh`: `gh alias list` once; for each wanted alias set it if missing or different (`--clobber`).
  - `preflight.sh`: `gh auth status --json` isn't available in all versions; use `gh auth status 2>&1` parsing "account X". For ctx in personal (+ work when profile has overlay): if `~/.config/dotfiles/gh_<ctx>` missing: if tty, print which account to log in with and run `gh auth login -h github.com -p ssh -w`? No: `gh auth login` is interactive itself; run it, then read the newly active account from `gh auth status` and remember it. Without tty print the command.
  - `shell.zsh`: `_dotfiles_gh_switch` on `chpwd`: determine ctx by `$PWD` prefix; read the remembered account; if `gh` present and the active account differs, `gh auth switch --user X >/dev/null 2>&1`. Cache the last ctx to avoid running gh on every cd within the same root.
- [ ] Commit `feat: gh module with two-account switching and PR aliases`.

### Task 4: profile, install, verify, docs

- [ ] `personal.toml` adds `lazygit`, `gh` (git already present). Dry run, real install on this Mac. Preflight asks to log in the personal gh account (Anand). Register the personal public key as a GitHub signing key (Anand, checklist). Make a signed commit in `~/personal/dotfiles` and verify "Good signature". `dots doctor` clean. CI + container green. STATUS updated. Commit `docs: phase 4 complete`.
