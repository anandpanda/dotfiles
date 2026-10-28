# Desktop Apps Implementation Plan

> Outcome (2026-10-28): the aerospace and karabiner modules were built, used for a
> day, and removed at Anand's request (tiling and the Caps Lock remap were not
> worth their complexity). Window arrangement is Raycast's snapping. The text
> below is the plan as executed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS desktop layer as modules: apps (casks), aerospace (tiling, TOML in repo), karabiner (Caps Lock → Escape/Hyper, JSON in repo), raycast (script commands + checklist). All free, all os-gated to macOS.

**Spec:** `docs/specs/06-apps.md`

## Global Constraints
All earlier. Tests never launch GUI apps; config validation uses the tools' own `--config`/`--check` where available and otherwise structural checks (TOML/JSON parse via python3). Modules carry `module.toml` `os = "macos"`.

## Review Focus
1. Karabiner rewrites karabiner.json on any change: the repo file must be byte-identical to what Karabiner writes back (key order, 4-space indent, trailing newline) or doctor nags forever (Task 3 test compares a round-trip through python json.dumps with Karabiner's format).
2. AeroSpace reads `~/.aerospace.toml` only when `~/.config/aerospace/aerospace.toml` is absent; the module must put it where AeroSpace reads first (Task 2 test checks only one location is linked).
3. Casks with `auto_updates`: doctor must not report them as outdated (Task 1).
4. Raycast's Cmd-Space conflicts with Spotlight until Spotlight's shortcut is disabled; the checklist says so, and the macos module's defaults do not try to script it (System Settings owns it).
5. AeroSpace plus Ghostty: Ghostty's own splits are inside one window and unaffected; test is manual (Task 4).

### Task 1: apps module
`modules/apps/{Brewfile.macos,module.toml,CHECKLIST.macos.md,doctor.sh,README.md}`, `tests/apps.bats`.
- Brewfile.macos: raycast, nikitabobko/tap/aerospace (via `tap` line), karabiner-elements, shottr, jordanbaird-ice, stats, alt-tab, todobar (browsers dropped during the build: their updaters lock the bundles), keka, appcleaner, monitorcontrol; `# cask "obsidian"` commented optional. Each with a why.
- doctor.sh: every uncommented cask in the Brewfile is in `brew list --cask`; missing → problem.
- Tests: Brewfile parses with brew_names; doctor with fake brew reports a missing cask and passes when all present; module gated to macos.
- Commit.

### Task 2: aerospace module
`modules/aerospace/{home/.config/aerospace/aerospace.toml,module.toml,README.md}`, `tests/aerospace.bats`.
- Config from the upstream default (config-version 2) with: start-at-login true, gaps inner 8 outer 8, alt-h/j/k/l focus, alt-shift-h/j/k/l move, alt-1..9 workspace, alt-shift-1..9 move-node-to-workspace, alt-f fullscreen, alt-slash layout tiles horizontal vertical, alt-comma accordion, alt-tab workspace-back-and-forth, alt-enter exec-and-forget open -na Ghostty, alt-shift-semicolon service mode (reload-config, reset layout). on-window-detected: Finder, System Settings, Raycast, Karabiner, Ice, Stats, Shottr → layout floating.
- Tests: TOML parses (python3 tomllib); the binds above present; floating rules present; `aerospace` running our config → `aerospace reload-config --dry-run --no-gui --warnings-as-errors` exits 0 (skip otherwise; there is no offline validator); only `~/.config/aerospace/aerospace.toml` linked.
- Commit.

### Task 3: karabiner module
`modules/karabiner/{home/.config/karabiner/karabiner.json,module.toml,doctor.sh,README.md}`, `tests/karabiner.bats`.
- karabiner.json: profiles[0] "dotfiles", selected true, complex_modifications.rules[0] Caps Lock → left_shift+ctrl+opt+cmd (lazy) on hold, escape alone, 200ms. Written with the exact formatting Karabiner uses (4-space indent, sorted keys as Karabiner emits).
- doctor.sh: if the live file differs from the repo copy after normalisation (python json load/dump), warn "karabiner changed outside the repo: review and commit" (info, not failure, like VS Code).
- Tests: valid JSON, manipulator present, doctor warns on drift and is quiet when equal.
- Commit.

### Task 4: raycast module, profile, install, verify, docs
`modules/raycast/{scripts/*.sh,home/.config/raycast/scripts (via home tree),module.toml,CHECKLIST.macos.md,README.md}`.
- One starter script command: `dots-doctor.sh` (runs dots doctor, Raycast shows the output). Checklist: Cmd-Space → Raycast (System Settings > Keyboard > Shortcuts > Spotlight off; Raycast hotkey), Cmd-Shift-V clipboard, add the scripts dir in Raycast > Extensions > Script Commands.
- personal.toml adds apps, aerospace, karabiner, raycast. Dry run; real install (casks download). Remove maccy, iterm2, cursor, codexbar casks/apps with Anand (brew uninstall --cask + AppCleaner for Cursor). Permissions prompts (Accessibility, Input Monitoring, Screen Recording) are Anand's: checklist walks them. Verify: Caps Lock Escape/Hyper, Raycast on Cmd-Space, Alt-h/l between two Ghostty windows, Alt-2 workspace. doctor clean. CI (macos job must not install casks that need a GUI? brew installs casks fine on the runner; AeroSpace/Karabiner casks install without launching). STATUS. Commit.
