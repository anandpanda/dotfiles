# Phase 2: Terminal core

Date: 2026-10-28
Status: draft, awaiting review

## Purpose

Everything that lives inside the terminal window: the app, the shell, the
prompt, history, multiplexer, the modern CLI stack, one theme and one font
across all of it. Built as modules on the Phase 1 foundation. Picks were
researched from zero and agreed with Anand; the runner-ups are recorded so
a swap later is a folder change, not a rethink.

## Picks

| Slot | Pick | Runner-up |
|------|------|-----------|
| Terminal app | Ghostty | Kitty, WezTerm |
| Shell | zsh | fish |
| Plugin manager | antidote (static mode) | zimfw |
| Prompt | Starship | powerlevel10k |
| History | atuin | zsh history |
| Multiplexer | tmux | Zellij |
| CLI stack | eza, bat, ripgrep, fd, zoxide, fzf, delta, yazi, dust, btop, jq, tealdeer | |
| Theme | Catppuccin Mocha everywhere | Tokyo Night |
| Font | JetBrains Mono Nerd Font | Monaspace |

## One foundation addition: shell integration per module

Any module may ship `shell.zsh`. `module_apply` links it to
`~/.config/zsh/rc.d/<module>.zsh`. The zsh module's `.zshrc` sources every
file in that directory in name order. This keeps each tool's shell hook in
the tool's own folder, and overlay modules get the same treatment for free.
`doctor` checks these links like any other. Covered by tests in
`tests/module.bats`.

## Modules

**zsh**
- `home/.zshenv`: sets `ZDOTDIR=~/.config/zsh` so every other zsh file
  lives in XDG, and exports `DOTFILES_DIR`.
- `config/.zshrc`: the only entry point. Order: options, antidote load,
  `rc.d/*.zsh`, aliases, local overrides (`~/.config/zsh/local.zsh`,
  gitignored, for machine-only tweaks).
- `config/.zsh_plugins.txt`: antidote bundle list, kept short:
  zsh-users/zsh-completions, zsh-users/zsh-autosuggestions,
  zsh-users/zsh-syntax-highlighting (last), plus fzf-tab.
- `config/aliases.zsh`: safe defaults (`rm -i` family), modern-tool aliases
  (`ls`→eza, `cat`→bat, `cd`→zoxide via `z`), git shorthands deferred to
  the git phase.
- `config/options.zsh`: history size, shared history off (atuin owns it),
  auto cd, correct, completion styling, keybinds (emacs mode, word moves).
- `Brewfile`: zsh, antidote.
- `install.sh`: if the login shell is not the brew zsh, print the exact
  `chsh` command in `CHECKLIST.md` output rather than running it (needs a
  password; left to Anand).
- Startup budget: under 80 ms measured with `zsh -i -c exit` timed ten
  times; antidote static mode and lazy loads keep it there. Measured in a
  test that runs only when zsh and antidote are present.

**starship**: `Brewfile`, `config/starship.toml` (Catppuccin Mocha palette,
two-line prompt, git status, language versions only inside projects,
command duration over 2 s), `shell.zsh` with the init line.

**atuin**: `Brewfile`, `config/config.toml` (local only, sync off until
Anand opts in, fuzzy search, Ctrl-R and up-arrow bound), `shell.zsh`.

**tmux**: `Brewfile` (tmux, tpm handled by `install.sh` cloning into
`~/.config/tmux/plugins/tpm`), `config/tmux.conf`: prefix Ctrl-a, mouse on,
vi copy mode, splits that keep the current path, 1-based windows,
Catppuccin plugin, tmux-resurrect and continuum for persistence,
tmux-sensible. `shell.zsh` adds a `ta` helper: attach or create a session
named after the current directory.

**ghostty**: `Brewfile` (cask on macOS, Linux via brew where available,
else `CHECKLIST.md` points to the official package), `config/config`:
Catppuccin Mocha, JetBrains Mono Nerd Font 14, shell integration, cursor,
window padding, a few keybinds for splits and tabs that mirror tmux's.
`module.toml` has no OS restriction; the Brewfile uses `cask` only on
macOS via a `brew_names` guard (the installer already drops casks on Linux
because `brew bundle` skips casks there).

**cli**: one `Brewfile` for the stack. `config/` holds per-tool configs that
the tools read from XDG paths: `bat/config` (theme, style), `btop/btop.conf`
(theme), `yazi/yazi.toml` + `theme.toml`. `shell.zsh` sets `FZF_DEFAULT_COMMAND`
to fd, previews with bat and eza, `fzf --zsh` keybinds, and the zoxide init.
Catppuccin themes for bat and btop are vendored under `config/` with their
upstream URL and license noted, since neither tool fetches themes itself.

**fonts**: `Brewfile` with `font-jetbrains-mono-nerd-font` (cask). On Linux,
`install.sh` downloads the Nerd Fonts release zip into
`~/.local/share/fonts` and runs `fc-cache`, idempotently.

**delta** lives in the cli Brewfile; its git config lands in the git phase.

## Profile

`personal.toml` gains: fonts, ghostty, zsh, starship, atuin, tmux, cli.
Order matters: fonts before ghostty; zsh before the modules that ship
`shell.zsh` so `rc.d` exists.

## Theme and font are the only cross-cutting choices

Catppuccin Mocha and JetBrains Mono Nerd Font appear in ghostty, starship,
tmux, bat, btop, yazi. A later VS Code phase uses the same two. Changing
either means editing those files; a theme switcher is out of scope.

## Out of scope

git config and aliases (phase 4), runtime managers (phase 5), any GUI app
other than the terminal (phase 6). Removing brew packages the old setup
installed that no module lists: doctor will show them as "extra" in a later
phase; nothing is uninstalled now.

## Testing

- Unit: `shell.zsh` linking in `module.bats`; each module's `install.sh`
  idempotent under a temp HOME; config files parse (`tmux -f conf -c true`
  style checks, `starship print-config`, `ghostty +show-config`) where the
  binary is present, otherwise skipped.
- Install on this Mac, open a new Ghostty window: prompt renders with
  glyphs, Ctrl-R opens atuin, `z` jumps, `ls` is eza with icons, `tmux`
  shows the Catppuccin bar, startup under 80 ms.
- Ubuntu container: install, reinstall no-op, doctor clean.
- CI as in Phase 1.
