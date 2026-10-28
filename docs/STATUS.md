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

## Pending for Anand

- Create `~/.secrets/github_token` when needed (doctor reminds).
- Work overlay: `just overlay-init ~/personal/dotfiles-work`, fill
  `modules/git/config/identity.work` (name, work-email@example.com), push to a private
  repo, then `just install work <url>` in a real terminal. That generates the
  work ssh key and sets the work git identity.
- Old configs are in `~/.dotfiles-backup/`. Old `~/.gitconfig` had delta,
  ssh signing, aliases; those return in the git phase.
- Replace `main` with `v2` when ready.

## Next: phases in order

2. Terminal core: shell, prompt, terminal app, multiplexer, history, modern CLI stack.
3. VS Code: settings, keybindings, extensions, snippets, theme as a module.
4. Git and GitHub workflow: delta, signing, aliases, lazygit or similar, worktrees, PR flow.
5. Runtimes and project tooling: mise, docker, direnv, language setups.
6. Mac and Linux apps: window manager, launcher, clipboard, browser, notes, todo.
7. Claude harness: CLAUDE.md layering, skills, agents, hooks, memory, statusline, plugins.
8. Learning layer: the parts of the harness that make Anand explain, review, go deep.

Each phase adds modules and profile entries only; the foundation does not change.
