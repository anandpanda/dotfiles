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

## Pending for Anand

- tmux plugins: start `tmux`, press Ctrl-a then Shift-i once.
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

(Phases 1 and 2 done. Use `dots <command>` from anywhere.)
3. VS Code: settings, keybindings, extensions, snippets, theme as a module.
4. Git and GitHub workflow: delta, signing, aliases, lazygit or similar, worktrees, PR flow.
5. Runtimes and project tooling: mise, docker, direnv, language setups.
6. Mac and Linux apps: window manager, launcher, clipboard, browser, notes, todo.
7. Claude harness: CLAUDE.md layering, skills, agents, hooks, memory, statusline, plugins.
8. Learning layer: the parts of the harness that make Anand explain, review, go deep.

Each phase adds modules and profile entries only; the foundation does not change.
