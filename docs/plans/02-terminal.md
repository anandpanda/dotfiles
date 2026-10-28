# Terminal Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seven modules (fonts, cli, zsh, starship, atuin, tmux, ghostty) on the Phase 1 foundation, plus two foundation additions: a preflight block that asks every human question up front, and per-module `shell.zsh` integration.

**Architecture:** `install.sh` installs packages, then runs every enabled module's `preflight.sh` (tty-aware), then configures unattended. `module_apply` links `shell.zsh` into `~/.config/zsh/rc.d/`. All zsh config lives in `~/.config/zsh` via `ZDOTDIR`. Catppuccin Mocha and JetBrains Mono Nerd Font are the only cross-cutting values. Plugins are pinned to tags.

**Tech Stack:** zsh 5.9, antidote 2.3 (static), starship 1.27, atuin 18, tmux 3.8 + tpm, ghostty, fzf 0.73, bats.

**Spec:** `docs/specs/02-terminal.md`

## Global Constraints

- All Phase 1 constraints (bash 3.2, DRY_RUN, never delete, no secrets, no-op reruns, shellcheck + shfmt, tests never touch real HOME).
- zsh files are linted with `zsh -n`. Configs are validated with the tool's own check where the binary exists, else the test skips.
- Plugin refs are pinned: zsh-completions `0.36.0`, zsh-autosuggestions `v0.7.1`, zsh-syntax-highlighting `0.8.0`, fzf-tab `v1.3.0`, tpm `v3.1.0`, tmux-sensible `v3.0.0`, tmux-resurrect `v4.0.0`, tmux-continuum `v3.1.0`, catppuccin/tmux `v2.3.2`. Verify each with `git ls-remote --tags` in the task that uses it.
- Interactive zsh startup under 80 ms (median of 10) on this Mac.
- macOS `defaults` never run with a fake HOME (guard from Phase 1).

## Review Focus

1. Preflight with no terminal and a missing login-shell switch: prints the two commands, continues, exit 0 (Task 1 test `preflight without tty prints and continues`).
2. `rc.d` sourcing when `~/.config/zsh/rc.d` does not exist yet (zsh module before any shell.zsh module): `.zshrc` must not error (Task 4 test `zshrc sources with empty rc.d`).
3. A `shell.zsh` from an overlay module with the same name as a public module: both must be linked, as `<name>.zsh` and `<name>.overlay.zsh` (Task 1 test `overlay shell.zsh does not clobber public`).
4. tpm clone when `~/.config/tmux/plugins/tpm` exists but at the wrong tag: must check out the pinned tag, not pull HEAD (Task 7 test `tpm at wrong tag is moved to pinned tag`).
5. fonts on Linux when `fc-cache` is missing: warn, do not fail (Task 2 test `fonts linux without fc-cache warns`).

---

## File Structure

```
lib/preflight.sh                 # preflight_run DIR...: runs each module's preflight.sh
lib/module.sh                    # + shell.zsh linking
install.sh                       # + preflight block before brew
doctor.sh                        # + rc.d link checks, login shell check
modules/fonts/{Brewfile,install.sh,README.md}
modules/cli/{Brewfile,shell.zsh,README.md,config/{bat/config,bat/themes/Catppuccin Mocha.tmTheme,btop/btop.conf,btop/themes/catppuccin_mocha.theme,yazi/yazi.toml,yazi/theme.toml,yazi/flavors/catppuccin-mocha.yazi/...}}
modules/zsh/{Brewfile,home/.zshenv,config/{.zshrc,.zsh_plugins.txt,options.zsh,aliases.zsh},preflight.sh,README.md,CHECKLIST.md}
modules/starship/{Brewfile,config/starship.toml,shell.zsh,README.md}
modules/atuin/{Brewfile,config/config.toml,shell.zsh,README.md}
modules/tmux/{Brewfile,config/tmux.conf,install.sh,shell.zsh,README.md}
modules/ghostty/{Brewfile,config/config,README.md}
tests/{preflight.bats,fonts.bats,cli.bats,zsh.bats,starship.bats,atuin.bats,tmux.bats,ghostty.bats}
```

Note on `cli/config`: `module_apply` links `config/` as a whole to `~/.config/cli`, which is not where bat, btop, yazi look. So the cli module uses `home/.config/bat`, `home/.config/btop`, `home/.config/yazi` instead (the `home/` tree lands at `~`). Same for any module whose tool name differs from the module name. The File Structure above is corrected accordingly in each task.

---

### Task 1: Foundation: preflight and shell.zsh

**Files:**
- Create: `lib/preflight.sh`, `tests/preflight.bats`
- Modify: `lib/module.sh` (shell.zsh linking), `install.sh` (preflight block, overlay url in preflight), `doctor.sh` (rc.d checks), `modules/ssh/install.sh` → split: key flow moves to `modules/ssh/preflight.sh`, `install.sh` keeps only `ssh_ensure_include`.
- Modify: `tests/module.bats`, `tests/ssh.bats`

**Interfaces:**
- Produces: `preflight_run DIR...` reads module dirs one per line on stdin, runs each `preflight.sh` with `DOTFILES_DIR HOME DRY_RUN DOTFILES_PROFILE` exported, in order, failing on non-zero. `module_apply` links `DIR/shell.zsh` to `~/.config/zsh/rc.d/<name>.zsh`, or `<name>.overlay.zsh` when DIR is inside the overlay. `rcd_dir` prints `$HOME/.config/zsh/rc.d`.

- [ ] **Step 1: Failing tests**

`tests/preflight.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log os link profile module preflight; do source "$DOTFILES_DIR/lib/$f.sh"; done
  M="$HOME/mods"; mkdir -p "$M/a" "$M/b"
  printf '#!/usr/bin/env bash\necho "a $DOTFILES_PROFILE" >> "$HOME/log"\n' > "$M/a/preflight.sh"
  printf '#!/usr/bin/env bash\necho b >> "$HOME/log"\n' > "$M/b/preflight.sh"
  export DOTFILES_PROFILE=test
}
teardown() { teardown_home; }

@test "runs preflights in order with env" {
  printf '%s\n%s\n' "$M/a" "$M/b" | preflight_run
  [ "$(cat "$HOME/log")" = $'a test\nb' ]
}

@test "module without preflight is skipped" {
  mkdir -p "$M/c"
  printf '%s\n' "$M/c" | preflight_run
  [ ! -f "$HOME/log" ]
}

@test "failing preflight fails the run" {
  printf '#!/usr/bin/env bash\nexit 2\n' > "$M/a/preflight.sh"
  run bash -c 'printf "%s\n" "'"$M/a"'" | preflight_run'
  [ "$status" -ne 0 ]
}
```

Append to `tests/module.bats`:
```bash
@test "shell.zsh links into rc.d" {
  mkdir -p "$M/tool"; echo 'echo hi' > "$M/tool/shell.zsh"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.config/zsh/rc.d/tool.zsh")" = "$M/tool/shell.zsh" ]
}

@test "overlay shell.zsh does not clobber public" {
  mkdir -p "$M/tool" "$HOME/.dotfiles-work/modules/tool"
  echo pub > "$M/tool/shell.zsh"; echo ovl > "$HOME/.dotfiles-work/modules/tool/shell.zsh"
  module_apply "$M/tool"; module_apply "$HOME/.dotfiles-work/modules/tool"
  [ "$(readlink "$HOME/.config/zsh/rc.d/tool.zsh")" = "$M/tool/shell.zsh" ]
  [ "$(readlink "$HOME/.config/zsh/rc.d/tool.overlay.zsh")" = "$HOME/.dotfiles-work/modules/tool/shell.zsh" ]
}
```

Append to `tests/install.bats`:
```bash
@test "preflight runs before modules and without tty continues" {
  mkdir -p "$DOTFILES_MODULES/one"
  printf '#!/usr/bin/env bash\necho PREFLIGHT\n' > "$DOTFILES_MODULES/one/preflight.sh"
  printf '#!/usr/bin/env bash\necho INSTALL\n' > "$DOTFILES_MODULES/one/install.sh"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [[ "$output" == *"PREFLIGHT"*"INSTALL"* ]]
  [[ "$output" == *"brew"*"PREFLIGHT"* ]] || [ "${DOTFILES_SKIP_BREW:-0}" = 1 ]
}
```

Replace the ssh tests that exercised `modules/ssh/install.sh` so they call `modules/ssh/preflight.sh` instead (same assertions). Add:
```bash
@test "ssh install.sh only ensures include" {
  run "$DOTFILES_DIR/modules/ssh/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ssh key"* ]]
  [ -f "$HOME/.ssh/config" ]
}
```

- [ ] **Step 2: Run, expect failures**: `bats tests/preflight.bats tests/module.bats tests/install.bats tests/ssh.bats`

- [ ] **Step 3: Implement**

`lib/preflight.sh`:
```bash
#!/usr/bin/env bash
# Everything that needs a human runs here, before anything changes.
# Reads module dirs one per line on stdin; runs each preflight.sh in order.

preflight_run() {
  local d name
  while IFS= read -r d; do
    [ -n "$d" ] && [ -f "$d/preflight.sh" ] || continue
    name="$(basename "$d")"
    log_info "preflight: $name"
    DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" \
      DOTFILES_PROFILE="${DOTFILES_PROFILE:-}" bash "$d/preflight.sh" ||
      {
        log_fail "preflight $name failed"
        return 1
      }
  done
  return 0
}
```

`lib/module.sh`, add before `module_apply`:
```bash
rcd_dir() { echo "$HOME/.config/zsh/rc.d"; }
```
and inside `module_apply`, after the `home/` block:
```bash
  if [ -f "$dir/shell.zsh" ]; then
    local rc="$(rcd_dir)/$name.zsh"
    _in_overlay "$dir" && rc="$(rcd_dir)/$name.overlay.zsh"
    link_file "$dir/shell.zsh" "$rc" || return 1
  fi
```

`install.sh`: source `preflight` in the lib loop; after the brew block and before module application:
```bash
log_info "preflight: anything that needs you"
printf '%s' "$module_dirs" | preflight_run || die "preflight failed"
```
Overlay url: move the `overlay_resolve_url` call into the preflight block so the prompt happens up front: `OVERLAY_URL="$(overlay_resolve_url "$OVERLAY_URL")"` right after the preflight line when `profile_has_overlay`; pass the resolved value to `overlay_apply` later.

`modules/ssh/preflight.sh` = old `install.sh` minus the include line. `modules/ssh/install.sh` = sources libs, `ssh_ensure_include` only.

`doctor.sh`: in the per-module loop add:
```bash
  if [ -f "$d/shell.zsh" ]; then
    rc="$HOME/.config/zsh/rc.d/$name.zsh"
    case "$d" in "$(overlay_dir)"/*) rc="$HOME/.config/zsh/rc.d/$name.overlay.zsh" ;; esac
    check_link "$d/shell.zsh" "$rc"
  fi
```

- [ ] **Step 4: Run, expect pass**: `bats tests` all green. `just lint`.
- [ ] **Step 5: Commit**: `git commit -m "feat: preflight block and per-module shell.zsh"`

---

### Task 2: fonts module

**Files:** `modules/fonts/{Brewfile,install.sh,README.md}`, `tests/fonts.bats`

- [ ] **Step 1: Failing tests**

```bash
load helper
setup() { setup_home; }
teardown() { teardown_home; }

@test "fonts install on linux downloads into ~/.local/share/fonts once" {
  [ "$(uname -s)" = Linux ] || skip "linux only"
  BIN="$HOME/bin"; mkdir -p "$BIN"
  printf '#!/usr/bin/env bash\nmkdir -p "$(dirname "${@: -1}")"; cd /tmp && zip -q "${@: -1}" /dev/null 2>/dev/null || touch "${@: -1}"\n' > "$BIN/curl"; chmod +x "$BIN/curl"
  printf '#!/usr/bin/env bash\necho fc\n' > "$BIN/fc-cache"; chmod +x "$BIN/fc-cache"
  PATH="$BIN:$PATH" run "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.local/share/fonts/JetBrainsMono" ]
}

@test "fonts on macos is a no-op script" {
  [ "$(uname -s)" = Darwin ] || skip "macos only"
  run "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
}

@test "fonts linux without fc-cache warns" {
  [ "$(uname -s)" = Linux ] || skip "linux only"
  mkdir -p "$HOME/.local/share/fonts/JetBrainsMono"
  PATH="/nonexistent" run bash "$DOTFILES_DIR/modules/fonts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fc-cache"* ]]
}
```

- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement**

`Brewfile`:
```ruby
# JetBrains Mono patched with Nerd Font glyphs (macOS cask; Linux handled by install.sh)
cask "font-jetbrains-mono-nerd-font"
```
`install.sh`:
```bash
#!/usr/bin/env bash
# Linux: install JetBrains Mono Nerd Font into the user font dir. macOS uses the cask.
set -euo pipefail
[ "$(uname -s)" = Linux ] || exit 0
dir="$HOME/.local/share/fonts/JetBrainsMono"
if [ -d "$dir" ]; then
  echo "skip $dir"
else
  if [ "${DRY_RUN:-0}" = 1 ]; then echo "[dry] download nerd font to $dir"; exit 0; fi
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/jb.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  mkdir -p "$dir" && unzip -qo "$tmp/jb.zip" -d "$dir" && rm -rf "$tmp"
  echo "installed $dir"
fi
if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$dir" >/dev/null; else echo "warn: fc-cache not found; install fontconfig"; fi
```
README: two lines.

- [ ] **Step 4: Run, expect pass.** **Step 5: Commit** `feat: fonts module`.

---

### Task 3: cli module

**Files:** `modules/cli/{Brewfile,shell.zsh,README.md}`, `modules/cli/home/.config/{bat/config,bat/themes/Catppuccin Mocha.tmTheme,btop/btop.conf,btop/themes/catppuccin_mocha.theme,yazi/yazi.toml,yazi/theme.toml,yazi/flavors/catppuccin-mocha.yazi/*}`, `tests/cli.bats`

- [ ] **Step 1: Failing tests**

```bash
load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "cli module links bat, btop, yazi configs and shell.zsh" {
  module_apply "$DOTFILES_DIR/modules/cli" >/dev/null
  [ -L "$HOME/.config/bat/config" ]
  [ -L "$HOME/.config/btop/btop.conf" ]
  [ -L "$HOME/.config/yazi/yazi.toml" ]
  [ -L "$HOME/.config/zsh/rc.d/cli.zsh" ]
}

@test "shell.zsh parses" {
  run zsh -n "$DOTFILES_DIR/modules/cli/shell.zsh"
  [ "$status" -eq 0 ]
}

@test "bat theme is wired and cached" {
  command -v bat >/dev/null || skip
  module_apply "$DOTFILES_DIR/modules/cli" >/dev/null
  bat cache --build >/dev/null
  run bat --list-themes
  [[ "$output" == *"Catppuccin Mocha"* ]]
}

@test "brewfile lists the stack" {
  for t in eza bat ripgrep fd zoxide fzf git-delta yazi dust btop jq tealdeer; do
    grep -q "\"$t\"" "$DOTFILES_DIR/modules/cli/Brewfile"
  done
}
```

- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement**

`Brewfile`:
```ruby
brew "eza"        # ls
brew "bat"        # cat with syntax highlighting
brew "ripgrep"    # grep
brew "fd"         # find
brew "zoxide"     # cd that learns
brew "fzf"        # fuzzy finder
brew "git-delta"  # diff pager (git config in phase 4)
brew "yazi"       # terminal file manager
brew "dust"       # du
brew "btop"       # top
brew "jq"         # json
brew "tealdeer"   # tldr pages
```
Vendor themes with `curl -fsSL` from the catppuccin repos at build time into the paths above, adding a `THEMES.md` noting source URLs and MIT license. `bat/config`:
```
--theme="Catppuccin Mocha"
--style=numbers,changes,header
--italic-text=always
```
`btop/btop.conf`: `color_theme = "catppuccin_mocha"`, `theme_background = False`, `vim_keys = True`, `rounded_corners = True`, `update_ms = 1000`. `yazi/theme.toml`: `[flavor] dark = "catppuccin-mocha"`. `yazi/yazi.toml`: `[mgr] show_hidden = true, sort_by = "natural", sort_dir_first = true`.

`shell.zsh`:
```zsh
# cli: fzf, zoxide, eza/bat defaults
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
(( $+commands[fzf] )) && source <(fzf --zsh)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
export BAT_THEME="Catppuccin Mocha"
export EZA_ICONS_AUTO=1
```

- [ ] **Step 4: Run, expect pass.** **Step 5: Commit** `feat: cli module with catppuccin themes`.

---

### Task 4: zsh module

**Files:** `modules/zsh/{Brewfile,home/.zshenv,config/.zshrc,config/.zsh_plugins.txt,config/options.zsh,config/aliases.zsh,preflight.sh,README.md,CHECKLIST.md}`, `tests/zsh.bats`
Also: `.gitignore` add `modules/zsh/config/local.zsh` and `modules/zsh/config/.zsh_plugins.zsh` (antidote's generated file) and `modules/zsh/config/.zcompdump*`.

Note: `config/` links to `~/.config/zsh`, which is `ZDOTDIR`. Antidote writes its static file next to the plugins list, inside the repo checkout; that is why it is gitignored.

- [ ] **Step 1: Failing tests**

```bash
load helper
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "zsh files parse" {
  for f in home/.zshenv config/.zshrc config/options.zsh config/aliases.zsh; do
    zsh -n "$DOTFILES_DIR/modules/zsh/$f"
  done
}

@test "zshenv sets ZDOTDIR" {
  run zsh -c "source '$DOTFILES_DIR/modules/zsh/home/.zshenv'; echo \$ZDOTDIR"
  [ "$output" = "$HOME/.config/zsh" ]
}

@test "zshrc sources with empty rc.d" {
  module_apply "$DOTFILES_DIR/modules/zsh" >/dev/null
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'echo ok'
  [ "$status" -eq 0 ]; [[ "$output" == *ok* ]]
}

@test "rc.d files are sourced in order" {
  module_apply "$DOTFILES_DIR/modules/zsh" >/dev/null
  mkdir -p "$HOME/.config/zsh/rc.d"
  echo 'echo one' > "$HOME/.config/zsh/rc.d/a.zsh"; echo 'echo two' > "$HOME/.config/zsh/rc.d/b.zsh"
  run env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c 'true'
  [[ "$output" == *$'one\ntwo'* ]]
}

@test "plugins are pinned to tags" {
  while read -r line; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    [[ "$line" == *"branch:"* ]]
  done < "$DOTFILES_DIR/modules/zsh/config/.zsh_plugins.txt"
}

@test "preflight without tty prints and continues" {
  run bash "$DOTFILES_DIR/modules/zsh/preflight.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chsh"* ]] || [[ "$output" == *"login shell ok"* ]]
}

@test "interactive startup under 80ms" {
  command -v antidote >/dev/null || skip "antidote missing"
  module_apply "$DOTFILES_DIR/modules/zsh" >/dev/null
  env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true  # warm: builds antidote static file
  t=$( { /usr/bin/time -p env HOME="$HOME" ZDOTDIR="$HOME/.config/zsh" zsh -i -c true; } 2>&1 | awk '/real/{print $2}')
  ms=$(printf '%.0f' "$(echo "$t * 1000" | bc)")
  [ "$ms" -lt 80 ]
}
```

- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement**

`home/.zshenv`:
```zsh
# Read by every zsh. Points zsh at XDG config; everything else lives there.
export ZDOTDIR="$HOME/.config/zsh"
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/personal/dotfiles}"
```

`config/.zshrc`:
```zsh
# Entry point for interactive shells. Order matters.
source "$ZDOTDIR/options.zsh"

# Homebrew on PATH (both OSes)
for p in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [[ -x $p ]] && eval "$($p shellenv)" && break
done

# Plugins via antidote, static mode: one generated file, regenerated when the list changes.
if [[ -r ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh ]]; then
  source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh"
  zsh_plugins="$ZDOTDIR/.zsh_plugins"
  if [[ ! $zsh_plugins.zsh -nt $zsh_plugins.txt ]]; then
    antidote bundle <"$zsh_plugins.txt" >|"$zsh_plugins.zsh"
  fi
  source "$zsh_plugins.zsh"
fi

# Per-module shell integration (modules/*/shell.zsh linked here by install)
if [[ -d $ZDOTDIR/rc.d ]]; then
  for f in "$ZDOTDIR"/rc.d/*.zsh(N); do source "$f"; done
fi

source "$ZDOTDIR/aliases.zsh"
[[ -r $ZDOTDIR/local.zsh ]] && source "$ZDOTDIR/local.zsh"
```

`config/.zsh_plugins.txt`:
```
# antidote bundle list. Pinned to tags via branch:. Order matters: syntax highlighting last.
zsh-users/zsh-completions branch:0.36.0 kind:fpath path:src
Aloxaf/fzf-tab branch:v1.3.0
zsh-users/zsh-autosuggestions branch:v0.7.1
zsh-users/zsh-syntax-highlighting branch:0.8.0
```

`config/options.zsh`:
```zsh
# History: big, deduped, appended; atuin owns search.
HISTFILE="$ZDOTDIR/.zsh_history"; HISTSIZE=100000; SAVEHIST=100000
setopt append_history inc_append_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks
# Navigation and correction
setopt auto_cd auto_pushd pushd_ignore_dups extended_glob no_beep interactive_comments
# Completion
autoload -Uz compinit && compinit -d "$ZDOTDIR/.zcompdump"
zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# Keys: emacs mode, word moves
bindkey -e
bindkey '^[[1;5C' forward-word; bindkey '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line; bindkey '^[[F' end-of-line
export EDITOR=code VISUAL=code
```

`config/aliases.zsh`:
```zsh
# Safety
alias rm='rm -i' cp='cp -i' mv='mv -i'
# Modern replacements (only when present)
(( $+commands[eza] )) && { alias ls='eza --group-directories-first'; alias ll='eza -la --git --group-directories-first'; alias lt='eza --tree --level=2'; }
(( $+commands[bat] )) && alias cat='bat --paging=never'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[btop] )) && alias top='btop'
(( $+commands[rg] )) && alias grep='rg'
(( $+commands[fd] )) && alias find='fd'
alias ..='cd ..' ...='cd ../..'
alias reload='exec zsh'
alias dot='cd $DOTFILES_DIR'
```

`preflight.sh`:
```bash
#!/usr/bin/env bash
# Make Homebrew zsh the login shell. Needs a password, so it runs in preflight.
set -euo pipefail
source "$DOTFILES_DIR/lib/log.sh"
for p in /opt/homebrew/bin/zsh /usr/local/bin/zsh /home/linuxbrew/.linuxbrew/bin/zsh; do
  [ -x "$p" ] && want="$p" && break
done
[ -n "${want:-}" ] || { log_warn "homebrew zsh not installed yet; rerun install after brew bundle"; exit 0; }
if [ "$(uname -s)" = Darwin ]; then cur="$(dscl . -read "$HOME" UserShell | awk '{print $2}')"; else cur="$(getent passwd "$USER" | cut -d: -f7)"; fi
[ "$cur" = "$want" ] && { log_ok "login shell ok ($want)"; exit 0; }
if [ "${DRY_RUN:-0}" = 1 ] || ! is_tty; then
  echo "to switch your login shell, run:"
  echo "  grep -qxF '$want' /etc/shells || echo '$want' | sudo tee -a /etc/shells"
  echo "  chsh -s '$want'"
  exit 0
fi
printf 'Switch login shell from %s to %s? [Y/n] ' "$cur" "$want"; read -r ans
case "$ans" in n | N) log_warn "kept $cur"; exit 0 ;; esac
grep -qxF "$want" /etc/shells || echo "$want" | sudo tee -a /etc/shells >/dev/null
chsh -s "$want" && log_ok "login shell is now $want (open a new terminal)"
```
Preflight runs after `brew bundle`, so Homebrew zsh is present on the first run and the switch happens in that same run.

`Brewfile`: `brew "zsh"`, `brew "antidote"`.

`doctor.sh`: add login shell check (same detection; `problem "login shell is $cur, expected $want"`).

- [ ] **Step 4: Run, expect pass** (startup test may skip until antidote is installed; it must pass after Task 9's install).
- [ ] **Step 5: Commit** `feat: zsh module with antidote, options, aliases, login shell preflight`.

---

### Task 5: starship module

**Files:** `modules/starship/{Brewfile,config/starship.toml,shell.zsh,README.md}`, `tests/starship.bats`

- [ ] **Step 1: Failing tests**: config links to `~/.config/starship`; `shell.zsh` parses; `starship config` loads it (`STARSHIP_CONFIG=... starship print-config >/dev/null`, skip if no binary).
- [ ] **Step 3: Implement**

`shell.zsh`: `export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"; (( $+commands[starship] )) && eval "$(starship init zsh)"`

`config/starship.toml` (Catppuccin Mocha palette block from the starship docs, two lines, directory truncated to 3, git branch and status, nodejs/python/golang/rust shown only inside projects, cmd_duration min 2000 ms, character `❯` green/red). Full file written in the task.

- [ ] **Step 5: Commit** `feat: starship module`.

---

### Task 6: atuin module

**Files:** `modules/atuin/{Brewfile,config/config.toml,shell.zsh,README.md}`, `tests/atuin.bats`

- [ ] Tests: links; `shell.zsh` parses; config has `auto_sync = false`.
- [ ] `config.toml`: `auto_sync = false`, `update_check = false`, `search_mode = "fuzzy"`, `filter_mode = "global"`, `style = "compact"`, `inline_height = 20`, `enter_accept = true`.
- [ ] `shell.zsh`: `(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"` with a comment that up-arrow stays plain zsh history; Ctrl-R is atuin.
- [ ] Commit `feat: atuin module`.

---

### Task 7: tmux module

**Files:** `modules/tmux/{Brewfile,config/tmux.conf,install.sh,shell.zsh,README.md}`, `tests/tmux.bats`

- [ ] **Step 1: Failing tests**: links; `tmux -f conf -L test start-server \; kill-server` parses (skip if no tmux); `install.sh` clones tpm at `v3.1.0` into `~/.config/tmux/plugins/tpm` (use a local bare repo with a tag as the "remote" via `TPM_REPO` env override); `tpm at wrong tag is moved to pinned tag`; rerun is a no-op; `ta` function parses.
- [ ] **Step 3: Implement**

`install.sh`:
```bash
#!/usr/bin/env bash
# Install tpm at a pinned tag. Plugins themselves are pinned in tmux.conf.
set -euo pipefail
dir="$HOME/.config/tmux/plugins/tpm"; tag=v3.1.0; repo="${TPM_REPO:-https://github.com/tmux-plugins/tpm.git}"
if [ "${DRY_RUN:-0}" = 1 ]; then echo "[dry] ensure tpm $tag at $dir"; exit 0; fi
if [ ! -d "$dir/.git" ]; then git clone -q --branch "$tag" --depth 1 "$repo" "$dir"; echo "installed tpm $tag"; exit 0; fi
if [ "$(git -C "$dir" describe --tags --exact-match 2>/dev/null)" != "$tag" ]; then
  git -C "$dir" fetch -q --tags && git -C "$dir" checkout -q "$tag" && echo "moved tpm to $tag"
else echo "skip tpm $tag"; fi
```

`config/tmux.conf` (key lines; full file in task):
```
set -g prefix C-a; unbind C-b; bind C-a send-prefix
set -g mouse on; set -g base-index 1; setw -g pane-base-index 1; set -g renumber-windows on
set -g default-terminal "tmux-256color"; set -ag terminal-overrides ",xterm-256color:RGB"
setw -g mode-keys vi
bind | split-window -h -c "#{pane_current_path}"; bind - split-window -v -c "#{pane_current_path}"
bind h select-pane -L; bind j select-pane -D; bind k select-pane -U; bind l select-pane -R
bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'catppuccin/tmux#v2.3.2'
set -g @catppuccin_flavor 'mocha'
set -g @continuum-restore 'on'
run '~/.config/tmux/plugins/tpm/tpm'
```
tpm pins: tpm supports `plugin#tag` syntax; use it for every plugin: `tmux-sensible#v3.0.0`, `tmux-resurrect#v4.0.0`, `tmux-continuum#v3.1.0`.

`shell.zsh`:
```zsh
# ta: attach to (or create) a tmux session named after the current directory
ta() { local n="${1:-${PWD:t}}"; tmux new-session -A -s "$n"; }
```
CHECKLIST: "inside tmux press prefix + I once to install plugins".

- [ ] **Step 5: Commit** `feat: tmux module`.

---

### Task 8: ghostty module

**Files:** `modules/ghostty/{Brewfile,config/config,README.md,CHECKLIST.md}`, `tests/ghostty.bats`

- [ ] Tests: links to `~/.config/ghostty/config`; `ghostty +show-config --config-file=... >/dev/null` when binary exists; Brewfile has the cask.
- [ ] `Brewfile`: `cask "ghostty"` (brew skips casks on Linux; CHECKLIST links the Linux package page).
- [ ] `config/config`:
```
theme = catppuccin-mocha
font-family = JetBrainsMono Nerd Font
font-size = 14
window-padding-x = 8
window-padding-y = 6
cursor-style = bar
cursor-style-blink = false
shell-integration = zsh
shell-integration-features = cursor,sudo,title
macos-option-as-alt = true
copy-on-select = clipboard
confirm-close-surface = false
keybind = cmd+d=new_split:right
keybind = cmd+shift+d=new_split:down
keybind = cmd+alt+left=goto_split:left
keybind = cmd+alt+right=goto_split:right
keybind = cmd+alt+up=goto_split:top
keybind = cmd+alt+down=goto_split:bottom
```
- [ ] Commit `feat: ghostty module`.

---

### Task 9: profile, install, verify, docs

- [ ] `profiles/personal.toml`: `modules = ["workspace", "secrets", "git", "ssh", "macos", "fonts", "cli", "zsh", "starship", "atuin", "tmux", "ghostty"]`.
- [ ] Vendor themes (Task 3) are committed; `.gitignore` entries added (Task 4).
- [ ] `just lint && just unit`.
- [ ] `just install personal --dry-run`, review with Anand, then `just install personal`. Expect the preflight block to ask about the login shell once (password), and nothing else.
- [ ] Open a new Ghostty window: prompt glyphs, `ls`, Ctrl-R, `z`, `tmux` then prefix+I. Startup test passes (`bats tests/zsh.bats`).
- [ ] `just doctor` clean; `just install personal` no-op; `just test` (Ubuntu) passes; push; CI green.
- [ ] Update `docs/STATUS.md`: Phase 2 done, picks table, pending items (tmux prefix+I, atuin sync opt-in). Commit `docs: phase 2 complete`.

---

## Self-review notes

- Spec coverage: preflight (T1), shell.zsh (T1), modules fonts/cli/zsh/starship/atuin/tmux/ghostty (T2-T8), login shell (T4 preflight + doctor), version policy (pinned refs in T4, T7), startup budget (T4 test), profile and install verification (T9).
- Review Focus 1→T4 preflight test, 2→T4 `zshrc sources with empty rc.d`, 3→T1 overlay shell.zsh test, 4→T7 tpm tag test, 5→T2 fc-cache test.
- Order is packages → preflight → configure, so one install does the whole job.
