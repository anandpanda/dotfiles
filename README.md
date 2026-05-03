# dotfiles

Portable, cross-platform dev environment + Claude Code config archive.

## Two halves

The repo has a clean separation:

1. **System tooling** (`install.sh`, `lib/`, `shell/`, `git/`) — `install.sh` deploys these. Tools, aliases, gitconfig.
2. **Claude Code config archive** (`claude/`) — pure reference. `install.sh` does NOT touch `~/.claude/`. You decide when and how to deploy.

## What's here

```
dotfiles/
├── install.sh                  # bootstrap system tooling (no Claude Code touching)
├── lib/                        # OS detection + per-OS install scripts
│   ├── common.sh               #   detect_os, need, have, apt_has, gh_install, log_*
│   ├── linux.sh                #   apt + GitHub static binary fallback
│   └── macos.sh                #   Homebrew
├── shell/
│   ├── aliases.sh              # universal nav + safety + modern CLI stack aliases
│   └── init.sh                 # tool integrations (fzf, zoxide, direnv, atuin)
├── git/
│   └── gitconfig               # identity, signing, delta as pager, aliases
├── configs/                    # tool configs — install.sh symlinks into ~/.config/
│   ├── zellij/config.kdl       #   Catppuccin Mocha, mouse, copy-on-select
│   ├── atuin/config.toml       #   sqlite-backed history, 10m auto-sync
│   ├── mise/config.toml        #   reads .nvmrc/.python-version, auto-install
│   ├── lazygit/config.yml      #   Catppuccin Mocha, delta pager, NF v3
│   ├── bat/config              #   Coldark-Dark theme, line numbers, italics
│   ├── btop/btop.conf          #   tokyo-night theme, vim keys, rounded corners
│   ├── ghostty/config          #   Catppuccin Mocha, JetBrainsMono NF, shell integ
│   └── starship/starship.toml  #   Catppuccin Mocha, two-line prompt
└── claude/                     # PURE REFERENCE — install.sh never touches this
    ├── settings.template.json  # ~/.claude/settings.json template (substitute $HOME)
    ├── statusline.sh           # custom Claude Code status line
    ├── hooks/                  # PreToolUse / SessionStart / Stop hooks
    │   ├── pre-tool-use.sh     #   asks before destructive ops + sensitive files
    │   ├── session-start.sh    #   injects git context for repos in workspace
    │   └── log-stop.sh         #   appends rich journal entry per turn
    ├── agents/                 # personal subagents (empty for now)
    ├── commands/               # personal slash commands (empty for now)
    ├── skills/                 # personal skills (empty for now)
    ├── CLAUDE.md               # personal Claude Code preferences (manual merge)
    └── memory/                 # behavioral memory archive (manual copy)

NOT in this repo (deliberately):
  claude/plans/                 # work-tied / project-specific
  claude/memory/project_*.md    # project-specific memory entries
  credentials                   # auth tokens — never sync
```

## Bootstrapping a new machine

```bash
git clone https://github.com/pandaAtZamp/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

`install.sh` is **idempotent** and:

1. Installs **system deps**: jq (required), gh, uv, semgrep
2. Installs the **modern CLI stack** (cross-platform, no Rust toolchain needed):
   - **Round 1**: bat, eza, fd, ripgrep, dust, duf, btop, sd, tldr, git-delta
   - **Round 2**: fzf, zoxide, direnv, atuin
   - **Round 3**: lazygit, zellij, mise, pnpm (via corepack), JetBrainsMono Nerd Font, gh extensions (gh-dash, gh-poi), zsh plugins (autosuggestions, syntax-highlighting, completions)
   - **Round 4**: Ghostty (macOS only — via brew cask; Linux ships config only, install via flathub on desktop Linux)
   - **Round 5**: starship (cross-shell prompt — overrides any existing p10k/oh-my-zsh theme)
   - Linux: apt where available; static binary from GitHub releases otherwise
   - macOS: Homebrew across the board
3. **Wires shell integrations + aliases** by appending `source <repo>/shell/init.sh` and `source <repo>/shell/aliases.sh` to `~/.zshrc.local` (init first, aliases after)
4. **Symlinks tool configs** from `configs/<tool>/` into `~/.config/<tool>/` (zellij, atuin, mise, lazygit, bat, btop). Edits at `~/.config/<tool>/<file>` flow back to the repo automatically. Pre-existing `~/.config/<tool>/` dirs are backed up to `*.backup.<timestamp>` before linking.

That's it. **`install.sh` does NOT touch `~/.claude/`.**

### Theme

All tools share **Catppuccin Mocha** (zellij, lazygit, fzf colors) plus matching dark themes for built-in ones (bat: Coldark-Dark, btop: tokyo-night). Set your terminal background to `#1e1e2e` for full cohesion.

## Deploying Claude Code config (manual, opt-in)

`~/dotfiles/claude/` is pure reference — your archive of "here's the config that works for me". Apply what you want, when you want, on each machine.

### Recommended: symlink-everything

After Claude Code is installed and you've run `claude login`:

```bash
# Hooks (each script symlinked individually)
mkdir -p ~/.claude/hooks
for f in ~/dotfiles/claude/hooks/*.sh; do
    ln -sf "$f" ~/.claude/hooks/$(basename "$f")
done

# Statusline
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh

# Settings (template substituted with $HOME)
sed "s|__HOME__|$HOME|g" ~/dotfiles/claude/settings.template.json > ~/.claude/settings.json

# (Optional) personal agents/commands/skills if you have any
for d in agents commands; do
    [ -d ~/dotfiles/claude/$d ] || continue
    mkdir -p ~/.claude/$d
    for f in ~/dotfiles/claude/$d/*; do
        [ -e "$f" ] || continue
        ln -sf "$f" ~/.claude/$d/$(basename "$f")
    done
done
for skill in ~/dotfiles/claude/skills/*/; do
    [ -d "$skill" ] || continue
    mkdir -p ~/.claude/skills
    ln -sf "${skill%/}" ~/.claude/skills/$(basename "$skill")
done
```

### Personal preferences (CLAUDE.md)

Manually merge into `~/.claude/CLAUDE.md` — never auto-deployed because each machine may have different preferences:

```bash
cat ~/dotfiles/claude/CLAUDE.md >> ~/.claude/CLAUDE.md
# then review ~/.claude/CLAUDE.md to dedupe and refine
```

### Memory entries

Manually copy specific behavioral memories you want active on this machine:

```bash
PROJECT_KEY=$(echo "$HOME/zamp" | sed 's|/|-|g')
mkdir -p ~/.claude/projects/$PROJECT_KEY/memory
cp ~/dotfiles/claude/memory/feedback_*.md \
   ~/.claude/projects/$PROJECT_KEY/memory/
```

## Auto-sync via symlinks

Once you've symlinked hooks/statusline/etc. into `~/.claude/`, **edits at `~/.claude/<thing>` flow back to the dotfiles repo automatically** (because the OS follows the symlink for writes too).

```bash
# Edit a hook
vim ~/.claude/hooks/log-stop.sh
# It actually writes to ~/dotfiles/claude/hooks/log-stop.sh
cd ~/dotfiles && git status   # shows the change
git add . && git commit -m "tweak: log-stop"
git push                      # when YOU decide; never auto-pushed
```

The exception: `~/.claude/settings.json` is generated from the template, not symlinked. To change settings durably, edit `~/dotfiles/claude/settings.template.json` and re-run the `sed` regeneration command above.

## Round 2 tools — opt-in steps

Most Round 2 tools work after install.sh + new shell session. Two require one-time per-machine action:

**atuin** — backfill existing zsh history into the sqlite db (one-time):
```bash
atuin import auto
```

**atuin sync** (optional, opt-in for cross-machine history):
```bash
# Once, on the first machine:
atuin register -u <username> -e <email>
# On other machines:
atuin login -u <username>
atuin sync
```

**Ctrl-R policy:** fzf keeps Ctrl-R for inline history search. atuin records to sqlite + syncs in background but does NOT grab keybindings. For archival/cross-device search, run `atuin search` directly.

If you prefer atuin's TUI for Ctrl-R: edit `shell/init.sh` and remove `--disable-ctrl-r --disable-up-arrow` from the atuin init line.

**direnv** — opt-in per project:
```bash
# In any project root:
echo 'export FOO=bar' > .envrc
direnv allow
# Now FOO is set when you cd into this dir; unset when you leave
```

## Round 3 tools — opt-in steps

**Nerd Font** — set your terminal's font to "JetBrainsMono Nerd Font" after install. Without this, prompt glyphs (icons in starship, p10k, etc.) render as boxes.

**mise** — install runtimes per project or globally:
```bash
mise use -g node@lts python@3.12   # global defaults
mise use node@20                   # per-project (creates .mise.toml)
```

**pnpm** — already enabled via corepack. First `pnpm <cmd>` call downloads pnpm itself (one-time, ~5MB).

**lazygit** — TUI for git. Run `lazygit` in any repo for full-screen status/stage/commit/log/branch UI.

**zellij** — terminal multiplexer. Run `zellij` to start a session. Built-in tutorial via the status bar at the bottom.

**gh extensions:**
- `gh dash` — interactive PR/issue dashboard
- `gh poi` — interactive cleanup of merged branches

## Environment variables

- `ZAMP_WORKSPACE` — path to your work workspace, used by Claude hooks for repo discovery. Defaults to `$HOME/zamp`. Override per-machine in `~/.zshrc.local` if your workspace is elsewhere.

## Updating across machines

```bash
# When you change something on the live machine:
# - Symlinked files (hooks, statusline, CLAUDE.md if you symlinked it):
#   edits already in repo via symlink, just commit
# - Non-symlinked files (settings.json):
#   edit ~/dotfiles/claude/settings.template.json by hand
# - Memory: copy to dotfiles archive if you want to share it across machines
cp ~/.claude/projects/.../memory/feedback_*.md ~/dotfiles/claude/memory/

cd ~/dotfiles
git add -A && git commit -m "update: <what changed>"
git push      # manual, when ready

# On other machines:
cd ~/dotfiles && git pull
bash install.sh    # picks up new tools or shell aliases
# Re-symlink ~/.claude/ items if you added new ones
```

## Caveats

- **Claude Code is not auto-deployed.** Each machine you set up requires the manual symlink commands. This is intentional — preferences and config are per-machine choices, not "must apply everywhere".
- **`~/.claude/.credentials.json` is never in the repo.** Run `claude login` per-machine.
- **Plugin sync is automatic** via Claude Code itself. As long as `~/.claude/settings.json` has the `enabledPlugins` block (regenerated from template), `claude` auto-installs missing plugins on first launch.
- **MCP server plugins may need their CLI deps.** `serena` needs `uvx` (auto-installed by install.sh). Other plugins you add later may need additional tools — install them separately or extend `lib/<os>.sh`.
