# Phase 3: VS Code

Date: 2026-10-28
Status: draft, awaiting review

## Purpose

VS Code as the main editor, fully owned by the repo: settings, keybindings,
snippets, tasks, and the exact extension list. Same theme and font as the
terminal. One module, `vscode`, plus the overlay convention for work-only
extensions.

## Picks (closed with Anand)

- Editor: VS Code from the Homebrew cask, a fresh install. On this Mac the
  hand-installed copy is moved to `~/.dotfiles-backup/` first so the cask
  installs clean and `just update` owns upgrades. Linux: Microsoft's apt repo
  via `install.sh` when apt exists, else a checklist line.
- Theme and icons: Catppuccin Mocha, Catppuccin icons.
- Font: JetBrains Mono Nerd Font 14, ligatures on, same in the integrated
  terminal. Terminal profile is Homebrew zsh as a login shell.
- AI: Claude Code extension. No Copilot (paid).
- Extensions (about 28): see `modules/vscode/extensions.txt`. Each line is
  `publisher.name  # one-line reason`. Groups: look, always-on, AI, Python
  (Ruff replaces Black and isort), Go, web (Prettier, ESLint, Tailwind),
  containers and remote, C++ (cpptools, Competitive Programming Helper, no
  CMake), GitHub (PRs, Actions), markdown and data (markdownlint, Rainbow
  CSV). Dropped list is recorded in `docs/STATUS.md`.
- Keybindings: VS Code defaults. `keybindings.json` ships empty with a
  comment saying so.
- Settings: format on save (Ruff for Python, Prettier for web, clang-format
  for C++), autosave on focus change, minimap off, sticky scroll on, bracket
  pair guides, trim trailing whitespace, insert final newline, git autofetch,
  no sync confirmation, no welcome page, smooth cursor, inlay hints off by
  default (noise), word wrap off, `files.exclude` for `.git`, `search.exclude`
  for `node_modules` and build dirs, window title shows project name.
- Tasks: a user-level `tasks.json` with one task, `cpp: build and run current
  file`, bound to Cmd-Shift-B / Ctrl-Shift-B via the default build task.
- Snippets: `cpp.json` with a contest template (`cp` trigger).
- Settings Sync: off. The repo is the sync. Documented in README.

## Module layout

```
modules/vscode/
├── Brewfile              # cask "visual-studio-code"
├── config/               # NOT linked as a dir: VS Code's user dir differs per OS
│   ├── settings.json
│   ├── keybindings.json
│   ├── tasks.json
│   └── snippets/cpp.json
├── extensions.txt
├── install.sh            # links config/* into the user dir; installs extensions
├── module.toml           # no os restriction
├── README.md
└── CHECKLIST.linux.md
```

`install.sh` resolves the user dir: macOS `~/Library/Application Support/Code/User`,
Linux `~/.config/Code/User`. It links each file in `config/` (and
`snippets/*`) with `link_file`, so the user dir stays a real directory and
VS Code's own state files are untouched. Then, if `code` is on PATH, it
installs every extension in `extensions.txt` not already present
(`code --list-extensions` compared once, then `code --install-extension`
per missing id). Dry run prints what would change. No `code` on PATH is a
warning, not a failure (first run on Linux before the app exists).

Overlay: an overlay `vscode` module may ship its own `extensions.txt`;
`install.sh` reads `$OVERLAY/modules/vscode/extensions.txt` too when present.
Work extensions (Coder remote) live there.

## Doctor

Reports as problems: missing config links, extensions in the list that are
not installed. Reports as info: installed extensions not in any list
(`extra`), so experiments are visible without failing. Skips extension
checks when `code` is not on PATH.

## Testing

- `settings.json`, `keybindings.json`, `tasks.json`, snippets parse as JSONC
  (comments stripped, then `json.loads`).
- `extensions.txt` parses; every id matches `^[a-z0-9-]+\.[a-z0-9-]+$`.
- `install.sh` with a fake `code` on PATH: installs only missing ids, is a
  no-op on rerun, honours dry run, links into the right user dir for the OS.
- doctor: missing link, missing extension, extra extension (info only).
- On this Mac: install, open VS Code, theme and font applied, `code
  --list-extensions` equals the list plus overlay, Cmd-Shift-B on a `.cpp`
  file builds and runs it.

## Out of scope

Language runtimes (phase 5). Cursor, installed on this Mac, is reviewed in
the app phase. Per-project `.vscode/` settings belong to each project.
