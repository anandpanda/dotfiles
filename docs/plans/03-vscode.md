# VS Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `vscode` module that owns settings, keybindings, tasks, snippets and the exact extension list, links them into VS Code's per-OS user dir, installs missing extensions idempotently, and is checked by doctor; plus one foundation addition so modules can ship their own doctor checks.

**Architecture:** `modules/vscode/config/*` are linked file by file by the module's `install.sh` (user dir differs per OS, so the generic `config/`→`~/.config/<name>` rule does not apply). Extensions come from `extensions.txt` (+ overlay's). Doctor gains a hook: any enabled module's `doctor.sh` runs and its non-zero exit counts as a problem. A `vscode-prune` command uninstalls extensions not on any list, after confirmation.

**Tech Stack:** bash 3.2, `code` CLI, Homebrew cask, bats, python3 for JSONC validation in tests.

**Spec:** `docs/specs/03-vscode.md`

## Global Constraints

- All Phase 1 and 2 constraints. Tests never touch the real VS Code user dir: tests set `HOME` and the module resolves the user dir under `$HOME`.
- `code` absent on PATH is a warning, never a failure, in install and doctor.
- JSON config files are JSONC (comments allowed) and must parse after comment stripping.

## Review Focus

1. `extensions.txt` with a trailing comment on an id line: the id must be parsed without the comment (Task 1 test `extension ids ignore comments`).
2. `code --list-extensions` returning ids in different case than the list: comparison must be case-insensitive (Task 2 test `extension compare is case-insensitive`).
3. Overlay `extensions.txt` present: its ids are installed too and not reported as extra (Task 2 and 3 tests).
4. User dir does not exist yet (fresh machine, VS Code never launched): install must create it and link (Task 2 test `creates the user dir`).
5. Module `doctor.sh` that exits non-zero: doctor exit 1 and the output shown (Task 3 test).

---

### Task 1: vscode module files

**Files:** `modules/vscode/{Brewfile,module.toml,README.md,CHECKLIST.linux.md,extensions.txt}`, `modules/vscode/config/{settings.json,keybindings.json,tasks.json,snippets/cpp.json}`, `lib/vscode.sh`, `tests/vscode.bats`

**Interfaces:**
- Produces: `vscode_user_dir` (prints `$HOME/Library/Application Support/Code/User` on macOS, `$HOME/.config/Code/User` on Linux), `vscode_ext_list FILE...` (prints ids one per line, comments and blanks stripped, lowercased), `jsonc_valid FILE` (0 if the file parses after comment stripping; uses python3).

- [ ] **Step 1: Failing tests**

`tests/vscode.bats`:
```bash
load helper
setup() { setup_home; for f in log os link module vscode; do source "$DOTFILES_DIR/lib/$f.sh"; done; V="$DOTFILES_DIR/modules/vscode"; }
teardown() { teardown_home; }

@test "user dir per os" {
  if [ "$(os_name)" = macos ]; then [ "$(vscode_user_dir)" = "$HOME/Library/Application Support/Code/User" ]; else [ "$(vscode_user_dir)" = "$HOME/.config/Code/User" ]; fi
}

@test "extension ids ignore comments and case" {
  printf '# group\nPub.Name  # why\n\nother.ext\n' > "$HOME/e.txt"
  run vscode_ext_list "$HOME/e.txt"
  [ "$output" = $'pub.name\nother.ext' ]
}

@test "shipped extension list is well formed" {
  run vscode_ext_list "$V/extensions.txt"
  [ "$status" -eq 0 ]; [ "${#lines[@]}" -ge 25 ]
  for id in "${lines[@]}"; do [[ "$id" =~ ^[a-z0-9-]+\.[a-z0-9-]+$ ]]; done
  [[ "$output" == *catppuccin.catppuccin-vsc* ]] && [[ "$output" == *charliermarsh.ruff* ]] && [[ "$output" == *anthropic.claude-code* ]]
  [[ "$output" != *black-formatter* ]] && [[ "$output" != *cmake* ]]
}

@test "config files are valid jsonc" {
  for f in settings.json keybindings.json tasks.json snippets/cpp.json; do jsonc_valid "$V/config/$f"; done
  ! jsonc_valid <(echo '{ bad')
}

@test "settings pin theme, font and terminal shell" {
  grep -q '"workbench.colorTheme": "Catppuccin Mocha"' "$V/config/settings.json"
  grep -q 'JetBrainsMono Nerd Font' "$V/config/settings.json"
  grep -q '"editor.formatOnSave": true' "$V/config/settings.json"
  grep -q 'charliermarsh.ruff' "$V/config/settings.json"
}
```

- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement**

`lib/vscode.sh`:
```bash
#!/usr/bin/env bash
# VS Code helpers: user dir per OS, extension list parsing, JSONC validation.

vscode_user_dir() {
  case "$(os_name)" in
    macos) echo "$HOME/Library/Application Support/Code/User" ;;
    *) echo "$HOME/.config/Code/User" ;;
  esac
}

# Ids one per line from FILE...; comments (# ...) and blanks dropped; lowercased.
vscode_ext_list() {
  cat "$@" | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '[:upper:]' '[:lower:]'
}

jsonc_valid() {
  python3 - "$1" <<'PY'
import json, re, sys
s = open(sys.argv[1]).read()
s = re.sub(r'(?m)^\s*//.*$', '', s)          # full-line comments
s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)   # block comments
s = re.sub(r',(\s*[}\]])', r'\1', s)          # trailing commas
json.loads(s)
PY
}
```

`modules/vscode/Brewfile`: `cask "visual-studio-code", args: { adopt: true }`
`modules/vscode/module.toml`: empty file is fine (no restriction); omit instead.
`modules/vscode/extensions.txt`: grouped with comments, the ~28 ids agreed (catppuccin.catppuccin-vsc, catppuccin.catppuccin-vsc-icons, usernamehw.errorlens, eamodio.gitlens, editorconfig.editorconfig, tamasfe.even-better-toml, redhat.vscode-yaml, dotenv.dotenv-vscode, aaron-bond.better-comments, mechatroner.rainbow-csv, davidanson.vscode-markdownlint, anthropic.claude-code, ms-python.python, ms-python.vscode-pylance, ms-python.debugpy, charliermarsh.ruff, golang.go, esbenp.prettier-vscode, dbaeumer.vscode-eslint, bradlc.vscode-tailwindcss, ms-azuretools.vscode-containers, ms-vscode-remote.remote-ssh, ms-vscode-remote.remote-ssh-edit, ms-vscode-remote.remote-containers, ms-vscode.cpptools, xaver.clang-format, divyanshuagrawal.competitive-programming-helper, github.vscode-pull-request-github, github.vscode-github-actions).

`config/settings.json` (JSONC, commented by section): look (theme, icons, font family/size/ligatures, cursor smooth, minimap off, sticky scroll, bracket guides, renderWhitespace boundary, rulers none), editing (formatOnSave, defaultFormatter prettier, per-language `[python]` ruff + organizeImports on save, `[cpp]` clang-format, `[go]` gofmt via extension), files (autoSave onFocusChange, trimTrailingWhitespace, insertFinalNewline, exclude .git/.DS_Store, watcherExclude node_modules), search (exclude node_modules, dist, build, .venv), git (autofetch, confirmSync false, enableSmartCommit), workbench (startupEditor none, title `${activeEditorShort}${separator}${rootName}`), terminal (fontFamily same, defaultProfile osx/linux = zsh with `-l`, scrollback 10000, cursor bar), telemetry off, update mode manual (brew owns updates), extensions.autoUpdate true, extensions.ignoreRecommendations false, security.workspace.trust prompt, errorLens minor tweaks, gitlens codeLens off (noise), cph: `cph.general.defaultLanguage: cpp`, `cph.language.cpp.Args: -std=c++17 -O2`.

`config/keybindings.json`: `// Defaults on purpose. Add only what the defaults can't do.` then `[]`.

`config/tasks.json`: version 2.0.0, one task "cpp: build and run current file": `g++ -std=c++17 -O2 -Wall "${file}" -o "${fileDirname}/${fileBasenameNoExtension}" && "${fileDirname}/${fileBasenameNoExtension}"`, group build default, presentation reveal always, problemMatcher `$gcc`.

`config/snippets/cpp.json`: `"Contest template"`, prefix `cp`, body: includes, `using namespace std`, fast io, `int main(){ int t; cin>>t; while(t--){ $0 } }`.

`README.md` and `CHECKLIST.linux.md` (`- vscode (Linux): install.sh adds Microsoft's apt repo; if your distro has no apt, see https://code.visualstudio.com/docs/setup/linux`).

- [ ] **Step 4: Run, expect pass.** Lint. **Step 5: Commit** `feat: vscode module files`.

---

### Task 2: vscode install.sh

**Files:** `modules/vscode/install.sh`, `tests/vscode.bats` (append)

**Interfaces:**
- Consumes: `vscode_user_dir`, `vscode_ext_list`, `link_file`, `overlay_dir`, `DRY_RUN`.
- Produces: links `config/{settings,keybindings,tasks}.json` and `config/snippets/*` into the user dir; installs missing extensions from `modules/vscode/extensions.txt` plus `$(overlay_dir)/modules/vscode/extensions.txt` if present; Linux: installs `code` via Microsoft apt repo when `apt-get` exists and `code` is absent.

- [ ] **Step 1: Failing tests** (fake `code` on PATH that logs calls and answers `--list-extensions` from `$HOME/installed.txt`):
`creates the user dir and links`, `installs only missing extensions`, `rerun is a no-op`, `extension compare is case-insensitive`, `overlay extensions are installed too`, `dry run installs nothing`, `no code on PATH warns and exits 0`.

- [ ] **Step 3: Implement** `install.sh`: source libs; `udir="$(vscode_user_dir)"`; dry-run aware `mkdir -p "$udir" "$udir/snippets"`; `link_file` each config file; Linux apt install block (idempotent, guarded by `command -v code`); if no `code`: warn, exit 0; build wanted list (`vscode_ext_list` of both files, sorted unique), installed list (`code --list-extensions | tr A-Z a-z | sort`), `comm -23` for missing, loop `code --install-extension "$id" --force >/dev/null && echo "installed $id"`; print `skip extensions` when none missing.

- [ ] **Step 4: pass, lint. Step 5: Commit** `feat: vscode install links config and installs extensions`.

---

### Task 3: module doctor hooks, vscode doctor, prune

**Files:** `doctor.sh` (hook), `modules/vscode/doctor.sh`, `scripts/vscode-prune.sh`, `justfile` (recipe), `tests/doctor.bats` (append), `tests/vscode.bats` (append)

- [ ] **Step 1: Failing tests**: doctor runs `modules/<m>/doctor.sh` for enabled modules, non-zero exit is a problem and output shown (generic test with a fake module); vscode doctor: `missing link reported`, `missing extension reported`, `extra extension is info not failure`, `overlay extension not extra`; prune: with fake `code`, `vscode-prune` lists extras and uninstalls after `y` from DOTFILES_TTY, `n` does nothing.

- [ ] **Step 3: Implement**
`doctor.sh`: after the link checks, loop enabled dirs: `[ -f "$d/doctor.sh" ] && { DOTFILES_DIR=... HOME=... bash "$d/doctor.sh" || problem "$(basename "$d") doctor"; }`.
`modules/vscode/doctor.sh`: check links (`[ -L ]` and target), skip extension checks without `code`; missing → print `missing extension X`, exit 1 at end; extras → print `extra extension X (dots vscode-prune)`, no failure.
`scripts/vscode-prune.sh`: compute extras the same way, print them, `ask "Uninstall these N extensions? [y/N] "`, uninstall each.
`justfile`: `vscode-prune: ./scripts/vscode-prune.sh`.

- [ ] **Step 5: Commit** `feat: module doctor hooks; vscode doctor and prune`.

---

### Task 4: profile, install on this Mac, verify, docs

- [ ] `profiles/personal.toml` adds `vscode`.
- [ ] `just lint && bats tests`. `dots install personal --dry-run`, then `dots install personal`: cask adopts the app, config linked, 3 new extensions installed.
- [ ] `dots vscode-prune` with Anand: ~40 extras removed. Coder remote goes to the work overlay later; until then it shows as extra (Anand keeps it: answer n, or prune then reinstall when the overlay exists). Decide with Anand.
- [ ] Open VS Code: Catppuccin, font, terminal is zsh with the prompt. Open a `.cpp`, type `cp` Tab, Cmd-Shift-B builds and runs.
- [ ] `dots doctor` clean. CI green. `docs/STATUS.md` Phase 3 section with the dropped list. Commit `docs: phase 3 complete`.

## Self-review notes
- Spec coverage: module files and picks (T1), per-OS linking and extension install incl. overlay and Linux apt (T2), doctor and extras and prune (T3), install/verify/docs (T4). Review Focus 1→T1, 2→T2, 3→T2+T3, 4→T2, 5→T3.
