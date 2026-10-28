# Project status

Read this first in a new session. It says where the project is and what comes next.

## What this is

Anand's personal dev environment package for macOS and Linux, built phase by
phase with Claude. Each phase: research options, pick with reasons, discuss,
spec, plan, build with tests, review, install on this laptop.

Working rules agreed with Anand:
- Start from zero; nothing carried from the old repo. The old `main` branch is
  the pre-revamp repo and will be replaced by `v2` when Anand says so.
- Every line readable and explainable. No dotfile manager.
- Free and open source first. Paid tools mentioned in one line, never defaulted.
- Public repo: no secrets, no company names, no overlay URL.
- VS Code is the main editor. Terminal stays first class.
- Anand wants to learn, not just be handed results: explain the why.
- Anand asked for concepts like paths, `~`, symlinks to be explained on the side.

## Done: Phase 1, foundation (branch `v2`, CI green)

Spec `docs/specs/01-foundation.md`, plan `docs/plans/01-foundation.md`.
Modules: workspace, secrets, git, ssh, macos. `just install|update|doctor|lint|unit|test`.
Installed on this Mac with the `personal` profile. Repos moved: work code under
`~/work`, personal under `~/personal` (this clone is `~/personal/dotfiles`).

All findings from the final review were fixed, including the minors.
Nothing is deferred.

## Done: Phase 2, terminal core (branch `v2`)

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

## Done: Phase 3, VS Code (branch `v2`)

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

## Done: Phase 4, git workflow (branch `v2`)

Spec `docs/specs/04-git.md`, plan `docs/plans/04-git.md`. Modules: git (grown),
lazygit, gh. Modern defaults (Chacon tiers 1-2 minus pruneTags/fetch.all),
delta + difftastic, SSH signing scoped to each identity with local
verification via ~/.local/state/git/allowed_signers, Conventional Commits
commit-msg hook via init.templateDir (install also adds it to existing repos
under ~/work and ~/personal), lazygit (Catppuccin, delta, VS Code), gh with
two accounts switched by a wrapper per directory, worktree helpers gwt/gwtl/gwtr,
pushf = --force-with-lease --force-if-includes.
Review: 0 critical, 7 important, 9 minor; all fixed, none deferred.

## Done: Phase 5, runtimes (branch `v2`)

Spec `docs/specs/05-runtimes.md`, plan `docs/plans/05-runtimes.md`. Modules:
mise (node lts, python, go, uv, pnpm; per-project pinning via mise.toml or the
idiomatic files; env and secrets via mise [env] / mise.local.toml; direnv
dropped as unsupported alongside mise), docker (Docker Desktop on macOS, free
tier covers small companies; engine via apt on Linux; lazydocker as `ld`).
Homebrew no longer owns runtimes: direnv go node poetry pyenv python@3.12
uninstalled; python@3.13/3.14 remain as dependencies of pre-commit/awscli/gcloud.
Linux parity: every module has a Linux path, tested on Ubuntu in CI and in the
container test (Ghostty via apt/snap, VS Code and Docker via apt, fonts via
release download). Only a Linux desktop-defaults module (gsettings) is left,
for Phase 6.

Phase 5 review: 1 critical (cached `mise activate` froze PATH), 7 important,
9 minor; all fixed, none deferred. Profiles now: personal, work, server
(headless Linux / Coder workspaces: terminal and git only), server-work.
Hooks follow one rule: present → skip; sudo usable → act; else print the
command and continue. `just test-server` installs the server profile as a user
with no sudo.

## Pending for Anand

- Coder remote (work) returns with the work overlay; until then
  `code --install-extension coder.coder-remote` if needed.
- Create `~/.secrets/github_token` when needed (doctor reminds).
- Work overlay: `just overlay-init ~/personal/dotfiles-work`, fill
  `modules/git/config/identity.work` (name, work email), push to a private
  repo, then `just install work <url>` in a real terminal.
- gh: `gh auth login -h github.com -p ssh` with the personal account, then
  `dots install personal` once so the wrapper can switch accounts.
- GitHub: register ~/.ssh/id_ed25519_personal.pub as a *Signing Key* so
  commits show "Verified" (they already verify locally).
- Old configs are in `~/.dotfiles-backup/`.
- Leftovers doctor found (need sudo): `sudo rm /etc/paths.d/10-pmk-global`
  (stale PATH entry) and `sudo rm -rf /usr/local/go /etc/paths.d/go` (go.dev
  Go shadowing mise's).
- Replace `main` with `v2` when ready.
- After all phases: a hands-on end-to-end walkthrough of the whole setup so
  Anand can use every part of it (Anand asked for this explicitly).

## Next: phases in order

(Phases 1 to 5 done. Use `dots <command>` from anywhere.)
5. Runtimes and project tooling: mise, docker, direnv, language setups.
6. Mac and Linux apps: window manager, launcher, clipboard, browser, notes, todo.
7. Claude harness: CLAUDE.md layering, skills, agents, hooks, memory, statusline, plugins.
8. Learning layer: the parts of the harness that make Anand explain, review, go deep.

Each phase adds modules and profile entries only; the foundation does not change.
