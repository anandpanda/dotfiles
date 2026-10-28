# Phase 6: Desktop apps (macOS)

Date: 2026-10-28
Status: approved by Anand (picks closed in conversation)

## Purpose

The desktop layer on a Mac: launcher, clipboard, window management, keyboard,
screenshots, menu bar, browser, quick todo, and the small utilities that each
remove one daily annoyance. Everything free. Work-managed apps (JumpCloud,
Falcon, VPN, Slack, Zoom) are IT's and stay out of the repo. Linux desktops are
out of scope: Anand's Linux use is headless (server profiles).

## Picks (closed)

| Slot | Pick | Why |
|------|------|-----|
| Launcher, clipboard history, snippets, window snapping | Raycast (free tier) | one app for four jobs; replaces Spotlight, Maccy, Rectangle |
| Tiling window manager | AeroSpace | 2026 developer consensus, TOML config in the repo, no SIP changes; opt-in via a profile flag until Anand decides to keep it |
| Keyboard | Karabiner-Elements | Caps Lock: Escape on tap, Hyper on hold; JSON config in the repo |
| Screenshots | Shottr | free, native, annotate, OCR, measure |
| Menu bar | Ice | hides icon clutter |
| System stats | Stats | CPU, memory, network in the menu bar |
| Window switcher | AltTab | Cmd-Tab with per-window previews |
| Browser | Brave (default) + Chrome (test target), hand-installed | Google's updater locks both bundles, so Homebrew cannot manage them; checklist covers a fresh machine |
| Quick todo | todobar | the menu-bar list Anand already uses daily |
| Utilities | Keka, AppCleaner, MonitorControl | archives, full uninstalls, external monitor brightness |
| Notes | none | Google Docs in the browser. Obsidian is a commented optional line |

Removed from this Mac: Maccy (Raycast), iTerm2 (Ghostty), Cursor, CodexBar.

## Modules

**apps**: one `Brewfile.macos` of casks (grouped, each with a why), `module.toml`
`os = "macos"`. `CHECKLIST.macos.md` lists the one-time permissions: Raycast
(Accessibility for window management), AeroSpace and AltTab (Accessibility),
Karabiner (Input Monitoring + the driver), Ice (Accessibility), Shottr (Screen
Recording). `doctor.sh`: each cask present (apps with `auto_updates` are not
upgraded by brew: that is fine, they update themselves).

**aerospace**: `home/.aerospace.toml` (AeroSpace reads only that path). Keys
mirror the rest of the setup: Alt-h/j/k/l focus, Alt-Shift-h/j/k/l move,
Alt-1..9 workspaces, Alt-Shift-1..9 move window to workspace, Alt-f fullscreen,
Alt-/ toggle tiles/accordion, Alt-Enter new Ghostty. Gaps 8. Finder, System
Settings, Raycast float. `start-at-login = true`. Enabled only when
`profiles/personal.toml` lists it; Anand can drop the line to go back to
Raycast snapping with nothing else changing.

**karabiner**: `home/.config/karabiner/karabiner.json` with one profile and one
complex modification (Caps Lock → Escape / Hyper). Karabiner rewrites this file
on save, so `doctor.sh` warns when the repo copy differs from the live one
(same pattern as VS Code: review and commit).

**raycast**: settings are encrypted on disk and cannot be tracked. The module
holds `scripts/` (Raycast script commands, plain files, linked into
`~/.config/raycast/scripts`) and `CHECKLIST.macos.md` with the hotkeys to set
once: Cmd-Space Raycast (replacing Spotlight), Cmd-Shift-V clipboard,
window snapping on Cmd-Opt-arrows when AeroSpace is off.

## Testing

- Brewfile lists every pick; aerospace.toml parses (`aerospace --config
  ... list-workspaces` dry check when installed, else key presence); karabiner.json
  is valid JSON with the caps_lock manipulator; doctor warns on karabiner
  drift; module os gating.
- On this Mac: install, grant permissions, Raycast on Cmd-Space, Caps Lock is
  Escape/Hyper, Shottr Cmd-Shift-2, AeroSpace tiles two Ghostty windows and
  Alt-2 switches workspace.

## Out of scope

Linux desktops, paid apps, work-managed apps, Spotlight configuration (Raycast
replaces it), Cursor.
