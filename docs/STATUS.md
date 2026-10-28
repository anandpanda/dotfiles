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

## Pending for Anand

- Coder remote (work) returns with the work overlay; until then
  `code --install-extension coder.coder-remote` if needed.
- Create `~/.secrets/github_token` when needed (doctor reminds).
- Work overlay: `just overlay-init ~/personal/dotfiles-work`, fill
  `modules/git/config/identity.work` (name, work email), push to a private
  repo, then `just install work <url>` in a real terminal.
- Old configs are in `~/.dotfiles-backup/`. Old gitconfig had delta, ssh
  signing, aliases; those return in the git phase.
- Replace `main` with `v2` when ready.
- After all phases: a hands-on end-to-end walkthrough of the whole setup so
  Anand can use every part of it (Anand asked for this explicitly).

## Next: phases in order

(Phases 1, 2 and 3 done. Use `dots <command>` from anywhere.)
4. Git and GitHub workflow: delta, signing, aliases, lazygit or similar, worktrees, PR flow.
5. Runtimes and project tooling: mise, docker, direnv, language setups.
6. Mac and Linux apps: window manager, launcher, clipboard, browser, notes, todo.
7. Claude harness: CLAUDE.md layering, skills, agents, hooks, memory, statusline, plugins.
8. Learning layer: the parts of the harness that make Anand explain, review, go deep.

Each phase adds modules and profile entries only; the foundation does not change.
