# Phase 1: Foundation

Date: 2026-10-28
Status: draft, awaiting review

## Purpose

One repo that turns a blank macOS or Linux machine into Anand's complete
personal dev environment with a single command, stays the source of
truth afterwards, and is tested like software. This phase builds the
skeleton every later phase plugs into. It ships no tool choices beyond
what the skeleton itself needs.

Guiding rules:

- Start from zero. Nothing is carried from the old repo.
- Every line is readable and explainable. No dotfile manager.
- Free and open source first.
- Public repo holds nothing work-confidential and no secret values.
- One tool, one folder. Adding or removing a tool touches one place.
- Both OSes are first class and tested on every push.

## Architecture

Four concepts:

1. **Module**: a self-contained folder for one tool. Holds its
   packages, config, shell integration, and optional install hook.
2. **Profile**: a list of enabled modules plus settings for a machine
   role. `personal` and `work` to start.
3. **Installer**: walks the enabled modules and applies them. Idempotent.
4. **Overlay**: a private repo with the same module shape, holding
   work-confidential modules. Enabled only by the `work` profile.

## Repo layout

```
dotfiles/
├── bootstrap.sh          # curl-able: installs git + brew, clones, runs install
├── justfile              # command surface: install, doctor, update, lint, test
├── lib/                  # installer internals, bash
│   ├── log.sh            # info/ok/warn/fail, colors, dry-run prefix
│   ├── os.sh             # OS + arch detection, brew prefix
│   ├── brew.sh           # install brew if missing, bundle all Brewfiles
│   ├── link.sh           # idempotent symlink with timestamped backup
│   ├── modules.sh        # resolve profile -> module list, apply each
│   └── overlay.sh        # clone/pull private overlay, apply its modules
├── install.sh            # entry: ./install.sh [profile] [--dry-run]
├── doctor.sh             # read-only drift report
├── profiles/
│   ├── personal.toml     # modules = [...]
│   └── work.toml         # extends personal, adds overlay = true
├── modules/
│   ├── <tool>/
│   │   ├── Brewfile      # packages for this tool only
│   │   ├── config/       # linked to ~/.config/<tool>/
│   │   ├── home/         # linked to ~/ (dotfiles that must live there)
│   │   ├── shell.zsh     # sourced by the shell module if present
│   │   ├── install.sh    # optional post-link hook, idempotent
│   │   └── README.md     # what, why, keybinds
│   ├── git/              # phase 1: config, identity includes, global ignore
│   ├── ssh/              # phase 1: host aliases
│   ├── macos/            # phase 1: defaults.sh in install.sh, mac only
│   ├── secrets/          # phase 1: creates ~/.secrets, manifest check
│   └── workspace/        # phase 1: creates ~/work, ~/personal
├── overlays/
│   └── work.example/     # documents overlay shape, no real data
├── .github/workflows/
│   └── ci.yml            # macos-latest + ubuntu-latest: install, doctor, lint
├── .editorconfig
├── .shellcheckrc
└── docs/specs/
```

Each module may omit any file. A module with only a Brewfile is valid.
Modules declare an OS restriction with a one-line `os = macos` in an
optional `module.toml`; the installer skips them elsewhere.

## Profiles

```toml
# profiles/personal.toml
modules = ["workspace", "secrets", "git", "ssh", "macos"]

# profiles/work.toml
extends = "personal"
overlay = "git@github.com:anandpanda/dotfiles-work.git"
```

Resolution: load `extends` chain, union module lists, then if `overlay`
is set, clone it to `~/.dotfiles-work` and apply every module inside its
`modules/` directory after the public ones. Overlay modules may carry
the same name as a public module; their files are linked on top.

The profile used is remembered in `~/.config/dotfiles/profile` so
`just update` and `just doctor` know which one to use without arguments.

## Installer behaviour

`./install.sh [profile] [--dry-run]`, default profile `personal`.

1. Detect OS. Abort unless macOS or Linux.
2. Ensure Homebrew, both OSes. On Linux also ensure `build-essential`,
   `curl`, `git` via apt first, since brew needs them.
3. Resolve profile to an ordered module list.
4. Concatenate all enabled modules' Brewfiles and run one `brew bundle`.
5. For each module in order: link `config/` to `~/.config/<module>/`,
   link `home/*` into `~/`, run `install.sh` if present.
6. Record the profile.
7. Print the manual checklist collected from modules (each module may
   ship a `CHECKLIST.md`).

Linking: a target that is already the correct symlink is skipped. Any
other existing target is moved to `~/.dotfiles-backup/<timestamp>/`
preserving its relative path. Nothing is ever deleted.

`--dry-run` logs every action with a `[dry]` prefix and changes nothing,
including no brew calls.

Second run on a configured machine: no brew changes, all links skipped,
exit 0 within seconds.

## Commands (justfile)

| command            | does |
|--------------------|------|
| `just install [p]` | full install with profile p |
| `just update`      | git pull, then install with remembered profile |
| `just doctor`      | drift report |
| `just lint`        | shellcheck + shfmt on all scripts |
| `just test`        | run install in a disposable Ubuntu container via docker |
| `just module name` | scaffold a new empty module folder |

`just` itself is in the bootstrap's brew install so the command surface
exists before anything else.

## Bootstrap

`bootstrap.sh` is safe to pipe to `sh` on a blank machine. It installs
Xcode CLT on macOS or apt basics on Linux, installs Homebrew, installs
git and just, clones the repo to `~/.dotfiles`, and runs
`just install personal`. It takes an optional profile argument.

## Phase 1 modules

**workspace**: creates `~/work` and `~/personal`.

**secrets**: creates `~/.secrets` mode 700. Ships `manifest.txt` listing
expected secret file names with one-line purposes. `install.sh` warns
for each missing one. `doctor` repeats the check. Nothing reads secrets
globally; projects use `direnv` later.

**git**: `home/.gitconfig` with no top-level user block and two
`includeIf gitdir:` rules pointing at `~/.config/git/identity.personal`
and `identity.work`. `config/identity.personal` holds name, email, and a
`url insteadOf` rewrite to the personal SSH alias. Work identity comes
from the overlay. Global ignore file. Committing outside `~/work` or
`~/personal` fails by design.

**ssh**: `home/.ssh/config` with `github.com-personal` and
`github.com-work` host aliases, each with `IdentitiesOnly yes` and its
own `IdentityFile`. Keys are never in a repo. `install.sh` warns if
expected key files are missing.

**macos**: `module.toml` restricts to macOS. `install.sh` applies
curated `defaults write` entries, each commented. Scope: keyboard repeat
and delay, no autocorrect or smart punctuation, Finder extensions and
path bar and list view, Dock autohide and no recents, screenshots to
`~/Screenshots` as png, tap to click, fast Mission Control animation.
Verified on macOS 26 before commit. Restarts Finder and Dock.

## Overlay contract

`overlays/work.example/` in the public repo shows the shape:

```
dotfiles-work/
└── modules/
    ├── git/config/identity.work
    ├── claude-work/home/work/CLAUDE.md     # lands at ~/work/CLAUDE.md
    └── ...
```

Overlay modules use the exact same layout and are applied by the same
code. The public repo contains no logic that knows what is inside the
overlay.

## Doctor

Read-only. Reports: brew packages in Brewfiles that are not installed,
links that are missing or point elsewhere, entries in `~/.config` not
owned by any module, missing secrets from the manifest, overlay present
and up to date, remembered profile. Exit code 1 if anything is off.

## CI

`.github/workflows/ci.yml` runs on push and PR:

- `macos-latest` and `ubuntu-latest` matrix
- `./install.sh personal`, then `./install.sh personal` again and assert
  no changes logged, then `./doctor.sh`
- `shellcheck` and `shfmt -d` on every `.sh` and `.zsh`

## Testing on this laptop

- `just install personal --dry-run` shows the plan.
- `just install personal`, then `just doctor` clean.
- `just install personal` again is a no-op.
- `just test` passes in an Ubuntu container.
- `git config user.email` differs between `~/work/x` and `~/personal/x`.

## Out of scope

Shell, prompt, terminal, editor, runtimes, apps, Claude harness. Each
is a later phase that adds modules and profile entries only.
