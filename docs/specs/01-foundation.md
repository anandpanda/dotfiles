# Phase 1: Foundation Design

Date: 2026-10-28
Status: draft, awaiting review

## Purpose

A single repo that turns a fresh macOS or Linux machine into Anand's
personal dev environment in one command, and that stays the source of
truth afterwards. This phase builds only the skeleton every later phase
hangs off: layout, install flow, personal/work overlay contract, git
identity switching, secrets convention, and macOS system defaults.

Guiding rules (agreed in conversation):

- Start from zero. Nothing is carried from the old repo by default.
- Every line is something Anand can read and explain. No dotfile manager.
- Free and open source first. Paid tools only mentioned, never defaulted.
- Public repo holds nothing work-confidential and no secret values.
- Phases are built one at a time; each ends installed and working.

## Non-goals for this phase

Tool choices for shell, terminal, editor, apps, and the Claude harness.
Those are later phases. This phase only reserves their places.

## Repo layout

```
dotfiles/
├── install.sh              # single entry point
├── doctor.sh               # drift check: repo vs machine
├── lib/
│   ├── log.sh              # info/warn/ok/fail helpers
│   ├── os.sh               # detect macos | linux, arch
│   ├── link.sh             # idempotent symlink with backup
│   └── pkg.sh              # brew / linux install helpers
├── packages/
│   ├── Brewfile            # macOS: cli, cask, fonts
│   └── linux/              # Linux: apt list + github-release installers
├── shell/                  # phase 2
├── git/
│   ├── config              # shared gitconfig with includeIf rules
│   ├── ignore              # global gitignore
│   └── identity.personal   # personal name/email/signing key
├── ssh/
│   └── config              # host aliases: github.com-personal, github.com-work
├── config/                 # one dir per tool, symlinked to ~/.config/<tool>
├── vscode/                 # phase 3
├── macos/
│   └── defaults.sh         # system defaults, idempotent
├── claude/                 # phase 7
├── overlays/
│   └── work.example/       # documents the overlay contract, no real data
└── docs/specs/             # design docs per phase
```

## Install flow

`./install.sh [--work] [--dry-run]`

1. Detect OS and arch. Abort on anything other than macOS or Linux.
2. Install package manager if missing (Homebrew on macOS, nothing on
   Linux; apt and GitHub releases are used directly).
3. Install packages from `packages/`.
4. Link every dir under `config/<tool>/` to `~/.config/<tool>/`, and
   the handful of home-level files (`git/config` to `~/.gitconfig`,
   `ssh/config` to `~/.ssh/config`, shell rc files). Existing files are
   moved to `~/.dotfiles-backup/<timestamp>/`, never deleted.
5. Create `~/work`, `~/personal`, `~/.secrets` if missing.
6. macOS only: run `macos/defaults.sh`.
7. If `--work`: clone or pull the private overlay repo into
   `~/.dotfiles-work` and run its `link.sh`.
8. Print a checklist of manual steps: secrets to populate, SSH keys to
   place, apps needing sign-in.

Every step is idempotent. Running install twice is safe and fast.
`--dry-run` prints what would change and touches nothing.

## Overlay contract

An overlay is a directory with the same shape as the main repo, holding
only the files that differ. The main repo ships `overlays/work.example/`
as documentation. The real work overlay is a private repo
`anandpanda/dotfiles-work` cloned to `~/.dotfiles-work`.

Overlay contents and where they land:

| In overlay              | Lands at                         | Purpose |
|-------------------------|----------------------------------|---------|
| `git/identity.work`     | `~/.config/git/identity.work`    | work name, email, key |
| `shell/work.sh`         | sourced by shell if present      | work aliases, env |
| `claude/CLAUDE.md`      | `~/work/CLAUDE.md`               | work AI conventions |
| `claude/.claude/`       | `~/work/.claude/`                | work skills, agents, settings |
| `mcp/.mcp.json`         | `~/work/.mcp.json`               | work MCP servers (refs only) |
| `link.sh`               | run by install.sh                | does the linking above |

The main repo never reads the overlay's contents. It only knows the
overlay exists and runs its `link.sh`. That keeps the boundary clean.

## Git identity switching

`git/config` sets no `[user]` block at top level. It contains:

```
[includeIf "gitdir:~/personal/"]
    path = ~/.config/git/identity.personal
[includeIf "gitdir:~/work/"]
    path = ~/.config/git/identity.work
```

Each identity file sets `user.name`, `user.email`, `user.signingkey`,
and a `url "git@github.com-<ctx>:".insteadOf = git@github.com:` rewrite
so clones inside that tree use the matching SSH alias automatically.

`ssh/config` defines `github.com-personal` and `github.com-work`, each
with its own `IdentityFile` and `IdentitiesOnly yes`. Existing keys
`id_ed25519_personal` and `id_ed25519_work` are reused; the keys
themselves are never in any repo.

A repo cloned outside `~/work` or `~/personal` has no identity and git
refuses to commit, which is the desired failure: it forces repos into
the right place.

## Secrets convention

`~/.secrets/` is a local-only directory, mode 700, never in any repo.

- One file per secret or per service, e.g. `~/.secrets/github_token`.
- Shell exports nothing from it globally. Projects pull what they need
  through `direnv` (`.envrc` reads from `~/.secrets/`).
- `install.sh` creates the directory and prints which files are
  expected, based on a `secrets.manifest` listing names and purposes.
- Migration to a remote password manager later is a change to how the
  files get populated, not to anything that reads them.

## macOS defaults

`macos/defaults.sh` applies a curated set, each line commented with what
it does. Scope for this phase: keyboard repeat and delay, disable
autocorrect and smart quotes, Finder (extensions, path bar, list view,
no warning on extension change), Dock (autohide, no recents, size),
screenshots to `~/Screenshots` as png, trackpad tap to click, fast
Mission Control animation. Verified against macOS 26 before commit.
Restarts Finder and Dock at the end.

## Doctor

`doctor.sh` reports: missing packages, broken or missing symlinks,
files in `~/.config` not managed by the repo, missing secrets from the
manifest, overlay present or not. Read-only. This replaces the drift
detection a dotfile manager would give.

## Testing

- `install.sh --dry-run` on this laptop shows the plan without changes.
- Full `install.sh` on this laptop, then `doctor.sh` reports clean.
- Running `install.sh` a second time changes nothing.
- A throwaway Linux container (Ubuntu via Docker) runs `install.sh`
  end to end without error.
- `git config user.email` inside `~/work/x` and `~/personal/x` return
  the two different identities.

## Open decisions

None blocking. Signing method (SSH signing vs GPG) is decided in the
git phase; the identity file shape supports either.
