# Project status

Read this first in a new session. It says where the project is and what comes next.

## What this is

Anand's personal dev environment package for macOS and Linux, built phase by
phase with Claude. Each phase: research options, pick with reasons, discuss,
spec, plan, build with tests, review, install on this laptop.

Working rules agreed with Anand:
- Start from zero; nothing carried from the old repo. The revamp was built on
  `v2` and replaced `main` on 2026-10-29; the pre-revamp history is the tag
  `archive/old-main`. Work continues on `main`.
- Every line readable and explainable. No dotfile manager.
- Free and open source first. Paid tools mentioned in one line, never defaulted.
- Public repo: no secrets, no company names, no overlay URL.
- VS Code is the main editor. Terminal stays first class.
- Anand wants to learn, not just be handed results: explain the why.
- Anand asked for concepts like paths, `~`, symlinks to be explained on the side.

## Done: Phase 1, foundation (CI green)

Spec `docs/specs/01-foundation.md`, plan `docs/plans/01-foundation.md`.
Modules: workspace, secrets, git, ssh, macos. `just install|update|doctor|lint|unit|test`.
Installed on this Mac with the `personal` profile. Repos moved: work code under
`~/work`, personal under `~/personal` (this clone is `~/personal/dotfiles`).

All findings from the final review were fixed, including the minors.
Nothing is deferred.

## Done: Phase 2, terminal core

Spec `docs/specs/02-terminal.md`, plan `docs/plans/02-terminal.md`.
Modules: fonts, cli, zsh, starship, atuin, tmux, ghostty. Foundation gained
a preflight block (packages → questions → configure) and per-module
`shell.zsh` hooks. Shell starts in ~65 ms, budget 80, tested.
A fresh review found 21 items; all fixed, none deferred. Notable: grep/find
are not aliased (rg -r means replace), plugin pins are enforced on existing
clones, prompts read the terminal directly, generated files never touch the repo.
Every config choice was walked through with Anand and closed:
Ghostty (Mocha, JetBrains Mono NF 14, cmd-d splits), zsh (4 pinned plugins,
emacs keys, modern aliases, XDG layout, Homebrew zsh login shell), Starship
(two lines, ssh-only hostname), atuin (Ctrl-R only, sync off), tmux (Ctrl-a,
pinned plugins, resurrect+continuum), CLI stack, fonts.

## Done: Phase 3, VS Code

Spec `docs/specs/03-vscode.md`, plan `docs/plans/03-vscode.md`. Module `vscode`:
settings, default keybindings, a C++ build-and-run task (Cmd-Shift-B), a `cp`
contest snippet, 34 extensions in `extensions.txt` installed idempotently
(plus the overlay's), per-OS user dir linking, doctor reports missing and
extra extensions, `dots vscode-prune` removes extras. Foundation gained
module `doctor.sh` hooks. Settings Sync stays off. Cask adopts the
hand-installed app.

Dropped from the old 70: vscode-icons, material-icon-theme, material-theme,
dark-plus-black, black-formatter, isort, gitblame, auto-import, autoimport,
auto-rename-tag, es7 snippets, ejs, mikestead.dotenv, docker pack/explorer/
vscode-docker, code-runner, live-server x2, jupyter x5, codespaces, remotehub,
azure-repos, remote-repositories, remote-server, codex-audio, codesnap,
gitignore, json-parse-stringify, pdf, sqlite-viewer, autodocstring,
vscode-python-envs, cpptools-themes, cmake, cmake-tools. Kept C++ and the
Competitive Programming Helper for Codeforces.

Phase 3 review: 1 critical (bits/stdc++.h on Apple clang: shim header now
linked to ~/.local/include), 7 important, 9 minor; all fixed, none deferred.
`dots vscode-prune` restores listed pack members after uninstalling packs.
`claudeCode.allowDangerouslySkipPermissions` is on by Anand's choice.
Doctor now reports uncommitted repo changes (VS Code writes through the links).

## Done: Phase 4, git workflow

Spec `docs/specs/04-git.md`, plan `docs/plans/04-git.md`. Modules: git (grown),
lazygit, gh. Modern defaults (Chacon tiers 1-2 minus pruneTags/fetch.all),
delta + difftastic, SSH signing scoped to each identity with local
verification via ~/.local/state/git/allowed_signers, Conventional Commits
commit-msg hook via init.templateDir (install also adds it to existing repos
under ~/work and ~/personal), lazygit (Catppuccin, delta, VS Code), gh with
two accounts switched by a wrapper per directory, worktree helpers gwt/gwtl/gwtr,
pushf = --force-with-lease --force-if-includes.
Review: 0 critical, 7 important, 9 minor; all fixed, none deferred.

## Done: Phase 5, runtimes

Spec `docs/specs/05-runtimes.md`, plan `docs/plans/05-runtimes.md`. Modules:
mise (node lts, python, go, uv, pnpm; per-project pinning via mise.toml or the
idiomatic files; env and secrets via mise [env] / mise.local.toml; direnv
dropped as unsupported alongside mise), docker (Docker Desktop on macOS, free
tier covers small companies; engine via apt on Linux; lazydocker as `ld`).
Homebrew no longer owns runtimes: direnv go node poetry pyenv python@3.12
uninstalled; python@3.13/3.14 remain as dependencies of pre-commit/awscli/gcloud.
Linux parity: every module has a Linux path, tested on Ubuntu in CI and in the
container test (Ghostty via apt/snap, VS Code and Docker via apt, fonts via
release download). A Linux desktop-defaults module (gsettings) was considered
and ruled out: Linux use is headless (Coder workspaces over SSH).

Phase 5 review: 1 critical (cached `mise activate` froze PATH), 7 important,
9 minor; all fixed, none deferred. Profiles now: personal, work, server
(headless Linux / Coder workspaces: terminal and git only), server-work.
Hooks follow one rule: present → skip; sudo usable → act; else print the
command and continue. `just test-server` installs the server profile as a user
with no sudo.

## Done: Phase 6, macOS desktop apps

Spec `docs/specs/06-apps.md`, plan `docs/plans/06-apps.md`. Modules (both
`os = "macos"`): apps (Brewfile: Raycast, Shottr, AltTab, todobar,
Keka, AppCleaner (Stats, Ice and MonitorControl removed 2026-10-30, unused); Obsidian commented optional; browsers
hand-installed because their updaters lock the bundles; the todobar tap cask
declared `trusted: true` for Homebrew 7; install.sh moves AltTab's hold key to
Command), raycast (script commands dir; `dots doctor` as a command; window
snapping on Cmd-Opt-arrows). AeroSpace tiling and the Karabiner Caps Lock remap
were built, tried for a day and removed at Anand's request: not worth their
complexity. Removed from this Mac: Maccy, iTerm2, Cursor, CodexBar, AeroSpace,
Karabiner, Homebrew runtimes and services, 19 GB of caches and leftovers.
Rulings: Docker Desktop stays (free tier); todobar kept; no notes app; no tiling
manager; services run in Docker, tools stay local.

Phase 6 review: 0 critical, 5 important, 15 minor; all fixed, none deferred.
mise 2026.10 resolves home from the user database, so tests point every mise
dir at the temp home; unit tests now also run on macOS in CI (bash 3.2).

## Done: Phase 7, Claude harness

Spec `docs/specs/07-claude-harness.md`, plan `docs/plans/07-claude-harness.md`.
Module `claude`: the working agreement (`CLAUDE.md`) and long-form rules,
`RESOLVER.md` naming one home per rule, eleven skills, three agents
(reviewer, researcher, worker), a statusline (model, context %, repo and
branch), and `settings.owned.json`, whose top-level keys are merged into
`~/.claude/settings.json` (model, effort and theme stay Anand's). Guard rails
are native permission rules that apply in bypass mode: deny for secret files
and `sops` decrypt, ask for merges, PR comments, `gh api` writes, pushes to
shared branches, force pushes and destructive git and docker commands. Plugins
(superpowers, security-guidance, pyright-lsp, typescript-lsp,
learning-output-style installed and off) and context7 are installed through
the claude CLI; doctor reports drift, missing plugins, and a missing jq or CLI.

Dropped, with why: the custom hooks (a secrets guard and a go-word gate, built
then replaced; formatter and context hooks) gave way to the native deny and ask rules, which Claude Code matches itself
and which hold in bypass mode, at Anand's call to trust rules and skills over
message-reading hooks; the skill trigger evals, because `claude plugin eval`
cannot run our format.

## Done: Phase 8, work layer

Spec `docs/specs/08-work-layer.md`, plan `docs/plans/08-work-layer.md`; the
private half lives in the overlay's `docs/08-work-layer.md`.
- Context folders: "work or personal" is decided by per-machine folder lists.
  Any module may ship `contexts/personal` or `contexts/work`; the git install
  collects them into `~/.config/dotfiles/contexts` and generates the git
  `includeIf` lines. The gh context function, the commit-hook install and the
  git doctor read the same lists. Public defaults: `~/personal`, `~/work`; the
  workspace module creates the folders it lists.
- The overlay checkout moved to `~/personal/dotfiles-work`, so it is a personal
  repo through the normal list. The overlay lists its own work folders.
- Settings fragments: any module may ship `claude-settings.json`; the claude
  module merges every active module's fragment into `~/.claude/settings.json`
  (deny and ask lists combined) and doctor checks the combined result. The
  overlay adds the work rules file, prod ask rules and a team-skill clash check.
- Claude Code itself is installed by the claude module with the official
  installer when it is missing.
- Link record: install records every link it makes in
  `~/.config/dotfiles/links`; a successful run removes links from the last
  record that it no longer makes, if they still point into the repo or the
  overlay. Doctor reports recorded links that dangle. Dry runs now run module
  install scripts in dry mode and walk the overlay, so they show the full plan.

## Pending for Anand

- Coder remote (work) returns with the work overlay; until then
  `code --install-extension coder.coder-remote` if needed.
- ~/.secrets/age.key has no off-device backup, by Anand's decision (2026-10-29):
  if this Mac is lost, secrets.yaml is lost and its contents are re-collected.
  Do not raise it again unless he asks.
- Work overlay: done 2026-10-29. A private repo on the personal account (it is
  Anand's config and follows him between jobs) holds the work identity, the
  cross-repo work CLIs, the work VS Code extensions, the work Claude rules and
  settings fragment, the work folders, and the work AWS profiles and kube
  contexts; the details live only there. Checked out at
  `~/personal/dotfiles-work`. `dots install work --overlay <url>` once; the url
  is remembered.
- Ruling (work dev setup, when Anand asks for it): servers and services
  (Postgres, Redis, queues, anything that listens on a port) run in Docker,
  per project via compose; CLIs, runtimes (mise), and the editor stay local.
- Coder half, decided 2026-10-30, parked until after Phase 7 at Anand's request:
  reuse the team's Coder template as is (it already has Coder's dotfiles
  module: set the workspace's "Dotfiles URL" parameter to this repo and
  `install.sh` runs on every start, no tty, log in ~/.dotfiles.log). No own
  template, no write to the team repo. Needed on our side first: (1)
  `~/.gitconfig` becomes a plain file that includes the repo config, because
  the template's commit-signing module runs `git config --global` and would
  write into the linked repo file; (2) `install.sh` detects a Coder workspace
  (CODER env) and defaults to the `server-work` profile; (3) the overlay's work
  module gets an install.sh that clones the standard repo set when missing.
  The template's own noise: extra clones, a company CLI, and a Claude bootstrap
  that writes ~/.claude/settings.json only if absent (Phase 7 writes it first).
  A fresh workspace prints a new work SSH key to register once.
  Principle: a Coder workspace is only a bigger machine; the dev setup on it is
  the same plain one as local (clone, mise, make), not the template's scripts.
- GitHub: register ~/.ssh/id_ed25519_personal.pub as a *Signing Key* so
  commits show "Verified" (they already verify locally).
- Old configs are in `~/.dotfiles-backup/`.
- A folder of old work checkouts with unpushed local branches (5.4 GB) stays
  until Anand decides; nothing else from the clutter review is left.
- After all phases: a hands-on end-to-end walkthrough of the whole setup so
  Anand can use every part of it (Anand asked for this explicitly).

## Next: phases in order

(Phases 1 to 8 done. Use `dots <command>` from anywhere.)
7. Claude harness: done (above). Secrets are guarded by the native deny rules
   in `modules/claude/settings.owned.json` (use `with-secrets`).
8. Work layer: done (above).
Next, in Anand's order (2026-10-31):
1. Hands-on end-to-end walkthrough of the Mac setup, one step at a time with
   his go: terminal, git and identities, secrets, AWS and kube, VS Code, apps,
   the Claude harness. Fix anything that does not feel right on the spot.
2. `/retro` on the Phase 7-8 session: first real run of the self-improving loop.
3. Coder, at the very end (reuse the team's template and its dotfiles hook;
   first question: how a workspace reaches the private overlay).
The learning-layer idea is folded into the explain, grill, retro and scout
skills; revisit only if real use shows a gap.

Each phase adds modules and profile entries only; the foundation does not change.
