# Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A modular, profile-driven dotfiles installer for macOS and Linux with a `just` command surface, guided SSH/overlay setup, a drift checker, a curl-able bootstrap, and CI on both OSes.

**Architecture:** Bash libraries under `lib/` are sourced by three entry scripts (`install.sh`, `doctor.sh`, `bootstrap.sh`). A profile resolves to an ordered module list; each module is a folder with optional `Brewfile`, `config/`, `home/`, `install.sh`, `module.toml`. The private work overlay is a second repo with the same `modules/` shape, applied after the public modules. Tests are `bats` files under `tests/` that run every library function against a temporary `$HOME`.

**Tech Stack:** bash 3.2+ (macOS default), Homebrew (both OSes), `just`, `bats-core`, `shellcheck`, `shfmt`, GitHub Actions, Docker for the Linux smoke test.

**Spec:** `docs/specs/01-foundation.md`

## Global Constraints

- Scripts must run under macOS stock bash 3.2 (no associative arrays, no `mapfile`, no `${var,,}`).
- Every library function must honour `DRY_RUN=1` by logging with a `[dry]` prefix and changing nothing.
- Nothing is ever deleted; replaced files move to `~/.dotfiles-backup/<timestamp>/`.
- No secret values, no company names, no overlay URL in the public repo.
- Second run of `install.sh` on a configured machine makes no changes and exits 0.
- All `.sh` files pass `shellcheck` and `shfmt -i 2 -ci -d`.
- Tests never touch the real `$HOME`; every test sets `HOME` to a temp dir.

## Review Focus

1. A target path exists as a regular file with the same content as the source: must still be backed up and replaced by a symlink, not silently skipped (Task 3 test `backs up identical regular file`).
2. A symlink pointing at the wrong source: must be backed up, not overwritten in place (Task 3 test `replaces wrong symlink`).
3. A profile that `extends` itself or forms a cycle: resolver must fail with a clear message, not loop (Task 4 test `rejects extends cycle`).
4. A module folder with only a `README.md` and nothing else: installer must apply it without error (Task 6 test `empty module is valid`).
5. `install.sh` run with no terminal and the `work` profile: must warn and skip keys and overlay, exit 0 (Task 8 test `non-tty skips guided steps`).

---

## File Structure

```
dotfiles/
├── bootstrap.sh
├── install.sh
├── doctor.sh
├── justfile
├── .editorconfig
├── .shellcheckrc
├── .gitignore
├── README.md
├── lib/
│   ├── log.sh        # log_info/ok/warn/fail/dry, die, is_tty
│   ├── os.sh         # os_name, os_arch, brew_prefix
│   ├── link.sh       # link_file SRC DST, backup_path DST
│   ├── profile.sh    # profile_modules NAME, profile_has_overlay NAME
│   ├── module.sh     # module_apply DIR NAME, module_enabled_for_os DIR
│   ├── brew.sh       # brew_ensure, brew_bundle_dirs DIR...
│   ├── ssh.sh        # ssh_ensure_key CTX EMAIL, ssh_test CTX
│   └── overlay.sh    # overlay_url, overlay_ensure URL, overlay_dir
├── profiles/
│   ├── personal.toml
│   └── work.toml
├── modules/
│   ├── workspace/{install.sh,README.md}
│   ├── secrets/{install.sh,manifest.txt,README.md}
│   ├── git/{home/.gitconfig,config/ignore,config/identity.personal,README.md}
│   ├── ssh/{home/.ssh/config,install.sh,README.md}
│   └── macos/{module.toml,install.sh,README.md}
├── overlays/work.example/{README.md,modules/git/config/identity.work.example}
├── tests/
│   ├── helper.bash
│   ├── log.bats, os.bats, link.bats, profile.bats, module.bats,
│   ├── ssh.bats, overlay.bats, install.bats, doctor.bats
├── scripts/
│   ├── new-module.sh
│   └── overlay-init.sh
└── .github/workflows/ci.yml
```

`.toml` profile files use a subset parsed by `sed`: `modules = ["a", "b"]`, `extends = "name"`, `overlay = true`. The `.toml` extension is kept because the subset is valid TOML and editors highlight it.

---

### Task 1: Repo scaffold, logging, OS detection

**Files:**
- Create: `.editorconfig`, `.shellcheckrc`, `.gitignore`, `justfile`, `lib/log.sh`, `lib/os.sh`, `tests/helper.bash`, `tests/log.bats`, `tests/os.bats`

**Interfaces:**
- Produces: `log_info MSG`, `log_ok MSG`, `log_warn MSG`, `log_fail MSG`, `log_dry MSG`, `die MSG` (exit 1), `is_tty` (0 if stdin and stdout are terminals), `os_name` (prints `macos` or `linux`), `os_arch` (prints `arm64` or `x86_64`), `brew_prefix` (prints Homebrew prefix for this OS/arch). `DOTFILES_DIR` env is set by every entry script to the repo root.

- [ ] **Step 1: Install test tooling**

```bash
brew install bats-core shellcheck shfmt just
```

- [ ] **Step 2: Write scaffold files**

`.editorconfig`:
```
root = true
[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

`.shellcheckrc`:
```
shell=bash
external-sources=true
source-path=SCRIPTDIR
```

`.gitignore`:
```
.DS_Store
*.local
```

`justfile`:
```
set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Full install with a profile (personal | work). Optional overlay url.
install profile="personal" *args="":
    ./install.sh {{profile}} {{args}}

# Pull latest and reinstall with the remembered profile
update:
    git -C "{{justfile_directory()}}" pull --ff-only
    ./install.sh

# Read-only drift report
doctor:
    ./doctor.sh

# shellcheck + shfmt on every script
lint:
    shellcheck install.sh doctor.sh bootstrap.sh lib/*.sh scripts/*.sh modules/*/install.sh
    shfmt -i 2 -ci -d install.sh doctor.sh bootstrap.sh lib scripts modules

# bats unit tests
unit:
    bats tests

# Smoke test the installer in a clean Ubuntu container
test:
    docker run --rm -v "{{justfile_directory()}}:/dotfiles:ro" ubuntu:24.04 bash -c \
      'apt-get update -qq && apt-get install -y -qq git curl sudo >/dev/null && cp -r /dotfiles /root/.dotfiles && cd /root/.dotfiles && ./install.sh personal && ./install.sh personal && ./doctor.sh'

# Scaffold a new module folder
module name:
    ./scripts/new-module.sh {{name}}

# Scaffold a new private overlay repo at path
overlay-init path:
    ./scripts/overlay-init.sh {{path}}
```

- [ ] **Step 3: Write failing tests for log and os**

`tests/helper.bash`:
```bash
# Shared setup for all bats files. Sources lib and isolates HOME.
setup_home() {
  export HOME
  HOME="$(mktemp -d)"
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export DRY_RUN=0
}
teardown_home() {
  rm -rf "$HOME"
}
```

`tests/log.bats`:
```bash
load helper
setup() { setup_home; source "$DOTFILES_DIR/lib/log.sh"; }
teardown() { teardown_home; }

@test "log_info prints message" {
  run log_info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "log_dry prefixes with [dry]" {
  run log_dry "would link"
  [[ "$output" == *"[dry]"*"would link"* ]]
}

@test "die exits 1 with message" {
  run die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}

@test "is_tty is false under bats" {
  run is_tty
  [ "$status" -ne 0 ]
}
```

`tests/os.bats`:
```bash
load helper
setup() { setup_home; source "$DOTFILES_DIR/lib/os.sh"; }
teardown() { teardown_home; }

@test "os_name is macos or linux" {
  run os_name
  [ "$status" -eq 0 ]
  [[ "$output" == "macos" || "$output" == "linux" ]]
}

@test "os_arch is arm64 or x86_64" {
  run os_arch
  [[ "$output" == "arm64" || "$output" == "x86_64" ]]
}

@test "brew_prefix is a known path" {
  run brew_prefix
  [[ "$output" == "/opt/homebrew" || "$output" == "/usr/local" || "$output" == "/home/linuxbrew/.linuxbrew" ]]
}
```

- [ ] **Step 4: Run tests, expect failure**

Run: `bats tests/log.bats tests/os.bats`
Expected: failures, `lib/log.sh: No such file`.

- [ ] **Step 5: Implement lib/log.sh and lib/os.sh**

`lib/log.sh`:
```bash
#!/usr/bin/env bash
# Logging helpers. Colors only when stdout is a terminal.

if [ -t 1 ]; then
  _c_blue=$'\033[34m' _c_green=$'\033[32m' _c_yellow=$'\033[33m' _c_red=$'\033[31m' _c_dim=$'\033[2m' _c_reset=$'\033[0m'
else
  _c_blue="" _c_green="" _c_yellow="" _c_red="" _c_dim="" _c_reset=""
fi

log_info() { printf '%s==>%s %s\n' "$_c_blue" "$_c_reset" "$*"; }
log_ok() { printf '%s ok%s %s\n' "$_c_green" "$_c_reset" "$*"; }
log_warn() { printf '%swarn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
log_fail() { printf '%sfail%s %s\n' "$_c_red" "$_c_reset" "$*" >&2; }
log_dry() { printf '%s[dry]%s %s\n' "$_c_dim" "$_c_reset" "$*"; }

die() {
  log_fail "$*"
  exit 1
}

# True when both stdin and stdout are terminals. Guided prompts need both.
is_tty() { [ -t 0 ] && [ -t 1 ]; }
```

`lib/os.sh`:
```bash
#!/usr/bin/env bash
# OS and architecture detection.

os_name() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    *) return 1 ;;
  esac
}

os_arch() {
  case "$(uname -m)" in
    arm64 | aarch64) echo arm64 ;;
    x86_64 | amd64) echo x86_64 ;;
    *) return 1 ;;
  esac
}

brew_prefix() {
  case "$(os_name)/$(os_arch)" in
    macos/arm64) echo /opt/homebrew ;;
    macos/x86_64) echo /usr/local ;;
    linux/*) echo /home/linuxbrew/.linuxbrew ;;
  esac
}
```

- [ ] **Step 6: Run tests, expect pass**

Run: `bats tests/log.bats tests/os.bats`
Expected: 7 tests, all pass.

- [ ] **Step 7: Lint and commit**

```bash
shellcheck lib/*.sh && shfmt -i 2 -ci -d lib
git add -A && git commit -m "feat: scaffold, log and os libraries with tests"
```

---

### Task 2: Symlink library with backup

**Files:**
- Create: `lib/link.sh`, `tests/link.bats`

**Interfaces:**
- Consumes: `log_*`, `DRY_RUN`.
- Produces: `link_file SRC DST` (makes DST a symlink to SRC, backing up anything in the way; creates parent dirs), `backup_root` (prints `$HOME/.dotfiles-backup/<run timestamp>`, same value for whole run), `link_tree SRC_DIR DST_DIR` (links every file under SRC_DIR to the same relative path under DST_DIR). All print `link`, `skip`, or `backup` lines; dry mode prints `[dry]` and does nothing.

- [ ] **Step 1: Write failing tests**

`tests/link.bats`:
```bash
load helper
setup() {
  setup_home
  source "$DOTFILES_DIR/lib/log.sh"
  source "$DOTFILES_DIR/lib/link.sh"
  SRC="$HOME/src"; mkdir -p "$SRC"; echo content > "$SRC/file"
}
teardown() { teardown_home; }

@test "links a new file and creates parent dirs" {
  link_file "$SRC/file" "$HOME/a/b/file"
  [ -L "$HOME/a/b/file" ]
  [ "$(readlink "$HOME/a/b/file")" = "$SRC/file" ]
}

@test "skips a correct existing symlink" {
  ln -s "$SRC/file" "$HOME/file"
  run link_file "$SRC/file" "$HOME/file"
  [[ "$output" == *"skip"* ]]
  [ -z "$(ls -A "$HOME/.dotfiles-backup" 2>/dev/null)" ]
}

@test "backs up identical regular file" {
  cp "$SRC/file" "$HOME/file"
  link_file "$SRC/file" "$HOME/file"
  [ -L "$HOME/file" ]
  [ "$(cat "$(backup_root)/file")" = "content" ]
}

@test "replaces wrong symlink and backs it up" {
  echo other > "$HOME/other"
  ln -s "$HOME/other" "$HOME/file"
  link_file "$SRC/file" "$HOME/file"
  [ "$(readlink "$HOME/file")" = "$SRC/file" ]
  [ -L "$(backup_root)/file" ]
}

@test "backs up a directory in the way" {
  mkdir -p "$HOME/dir"; echo x > "$HOME/dir/inner"
  link_file "$SRC" "$HOME/dir"
  [ -L "$HOME/dir" ]
  [ -f "$(backup_root)/dir/inner" ]
}

@test "dry run changes nothing" {
  DRY_RUN=1 run link_file "$SRC/file" "$HOME/file"
  [[ "$output" == *"[dry]"* ]]
  [ ! -e "$HOME/file" ]
}

@test "link_tree links every file preserving relative paths" {
  mkdir -p "$SRC/tree/.ssh"; echo c > "$SRC/tree/.ssh/config"; echo g > "$SRC/tree/.gitconfig"
  link_tree "$SRC/tree" "$HOME"
  [ "$(readlink "$HOME/.ssh/config")" = "$SRC/tree/.ssh/config" ]
  [ "$(readlink "$HOME/.gitconfig")" = "$SRC/tree/.gitconfig" ]
}

@test "fails when source missing" {
  run link_file "$SRC/nope" "$HOME/file"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run, expect failure**

Run: `bats tests/link.bats`
Expected: all fail, `link.sh: No such file`.

- [ ] **Step 3: Implement lib/link.sh**

```bash
#!/usr/bin/env bash
# Idempotent symlinking with timestamped backups. Never deletes.

: "${DRY_RUN:=0}"
_backup_root=""

backup_root() {
  if [ -z "$_backup_root" ]; then
    _backup_root="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
  fi
  echo "$_backup_root"
}

# Move DST into the backup tree, preserving its path relative to HOME.
_backup() {
  local dst="$1" rel dest
  rel="${dst#"$HOME"/}"
  dest="$(backup_root)/$rel"
  if [ "$DRY_RUN" = 1 ]; then
    log_dry "backup $dst -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  mv "$dst" "$dest"
  printf 'backup %s -> %s\n' "$dst" "$dest"
}

link_file() {
  local src="$1" dst="$2"
  [ -e "$src" ] || [ -L "$src" ] || { log_fail "link source missing: $src"; return 1; }

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf 'skip %s\n' "$dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    _backup "$dst"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log_dry "link $dst -> $src"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  printf 'link %s -> %s\n' "$dst" "$src"
}

# Link every regular file under SRC_DIR to the same relative path in DST_DIR.
link_tree() {
  local src_dir="$1" dst_dir="$2" f rel
  while IFS= read -r f; do
    rel="${f#"$src_dir"/}"
    link_file "$f" "$dst_dir/$rel"
  done < <(find "$src_dir" -type f | sort)
}
```

- [ ] **Step 4: Run, expect pass**

Run: `bats tests/link.bats`
Expected: 8 pass.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck lib/link.sh && shfmt -i 2 -ci -d lib && git add -A && git commit -m "feat: link library with backup and dry run"
```

---

### Task 3: Profile resolution

**Files:**
- Create: `lib/profile.sh`, `profiles/personal.toml`, `profiles/work.toml`, `tests/profile.bats`

**Interfaces:**
- Consumes: `die`, `DOTFILES_DIR`.
- Produces: `profile_modules NAME` (prints module names one per line, extends chain first, deduplicated, order preserved), `profile_has_overlay NAME` (exit 0 if any profile in the chain sets `overlay = true`), `profile_file NAME` (prints path or fails), `state_dir` (prints `$HOME/.config/dotfiles`), `remember KEY VALUE`, `recall KEY` (plain files under state dir).

- [ ] **Step 1: Write profile files**

`profiles/personal.toml`:
```toml
# Modules applied on every machine. Order matters: earlier first.
modules = ["workspace", "secrets", "git", "ssh", "macos"]
```

`profiles/work.toml`:
```toml
# Everything in personal, plus the private overlay repo.
extends = "personal"
overlay = true
```

- [ ] **Step 2: Write failing tests**

`tests/profile.bats`:
```bash
load helper
setup() {
  setup_home
  source "$DOTFILES_DIR/lib/log.sh"
  source "$DOTFILES_DIR/lib/profile.sh"
  PROFILES="$HOME/profiles"; mkdir -p "$PROFILES"
  export DOTFILES_PROFILES="$PROFILES"
  printf 'modules = ["a", "b"]\n' > "$PROFILES/base.toml"
  printf 'extends = "base"\nmodules = ["b", "c"]\noverlay = true\n' > "$PROFILES/child.toml"
  printf 'extends = "loop2"\n' > "$PROFILES/loop1.toml"
  printf 'extends = "loop1"\n' > "$PROFILES/loop2.toml"
}
teardown() { teardown_home; }

@test "base profile lists its modules" {
  run profile_modules base
  [ "$output" = $'a\nb' ]
}

@test "child unions parent first, deduplicated" {
  run profile_modules child
  [ "$output" = $'a\nb\nc' ]
}

@test "overlay flag follows the chain" {
  run profile_has_overlay base; [ "$status" -ne 0 ]
  run profile_has_overlay child; [ "$status" -eq 0 ]
}

@test "unknown profile fails" {
  run profile_modules nope
  [ "$status" -ne 0 ]
}

@test "rejects extends cycle" {
  run profile_modules loop1
  [ "$status" -ne 0 ]
  [[ "$output" == *"cycle"* ]]
}

@test "remember and recall round trip" {
  remember profile work
  [ "$(recall profile)" = "work" ]
  [ -f "$HOME/.config/dotfiles/profile" ]
}

@test "recall of unset key prints nothing and fails" {
  run recall missing
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "real profiles resolve" {
  unset DOTFILES_PROFILES
  run profile_modules work
  [[ "$output" == *"git"* ]]
  run profile_has_overlay work; [ "$status" -eq 0 ]
  run profile_has_overlay personal; [ "$status" -ne 0 ]
}
```

- [ ] **Step 3: Run, expect failure**

Run: `bats tests/profile.bats`

- [ ] **Step 4: Implement lib/profile.sh**

```bash
#!/usr/bin/env bash
# Profile files are a TOML subset: modules = [...], extends = "name", overlay = true.

profiles_dir() { echo "${DOTFILES_PROFILES:-$DOTFILES_DIR/profiles}"; }

profile_file() {
  local f
  f="$(profiles_dir)/$1.toml"
  [ -f "$f" ] || { log_fail "unknown profile: $1"; return 1; }
  echo "$f"
}

_toml_string() { # FILE KEY -> value of key = "value"
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}
_toml_bool_true() { # FILE KEY -> 0 if key = true
  grep -Eq "^[[:space:]]*$2[[:space:]]*=[[:space:]]*true" "$1"
}
_toml_list() { # FILE KEY -> items one per line
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\[\(.*\)\].*/\1/p" "$1" |
    tr ',' '\n' | sed 's/[[:space:]"]//g' | grep -v '^$' || true
}

# Prints the chain root-first: base child ...
_profile_chain() {
  local name="$1" seen="${2:-}" file parent
  case " $seen " in *" $name "*) log_fail "profile extends cycle at: $name"; return 1 ;; esac
  file="$(profile_file "$name")" || return 1
  parent="$(_toml_string "$file" extends)"
  if [ -n "$parent" ]; then
    _profile_chain "$parent" "$seen $name" || return 1
  fi
  echo "$name"
}

profile_modules() {
  local chain p file m out=""
  chain="$(_profile_chain "$1")" || return 1
  for p in $chain; do
    file="$(profile_file "$p")"
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      case " $out " in *" $m "*) ;; *) out="$out $m" ;; esac
    done <<EOF
$(_toml_list "$file" modules)
EOF
  done
  printf '%s\n' $out
}

profile_has_overlay() {
  local chain p
  chain="$(_profile_chain "$1")" || return 1
  for p in $chain; do
    _toml_bool_true "$(profile_file "$p")" overlay && return 0
  done
  return 1
}

state_dir() { echo "$HOME/.config/dotfiles"; }
remember() { mkdir -p "$(state_dir)"; printf '%s\n' "$2" > "$(state_dir)/$1"; }
recall() { [ -f "$(state_dir)/$1" ] && cat "$(state_dir)/$1"; }
```

- [ ] **Step 5: Run, expect pass**

Run: `bats tests/profile.bats`
Expected: 8 pass.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck lib/profile.sh && git add -A && git commit -m "feat: profile resolution with extends and overlay flag"
```

---

### Task 4: Module application

**Files:**
- Create: `lib/module.sh`, `tests/module.bats`, `scripts/new-module.sh`

**Interfaces:**
- Consumes: `link_file`, `link_tree`, `log_*`, `os_name`, `DRY_RUN`.
- Produces: `module_enabled_for_os DIR` (0 unless `module.toml` has `os = "<other>"`), `module_apply DIR` (links `config/` to `~/.config/<basename>`, links `home/` tree into `$HOME`, runs `install.sh` with `DOTFILES_DIR`, `HOME`, `DRY_RUN` exported), `module_brewfiles DIR...` (prints paths of existing Brewfiles), `module_checklists DIR...` (cats every `CHECKLIST.md`).

- [ ] **Step 1: Write failing tests**

`tests/module.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  M="$HOME/mods"; mkdir -p "$M"
}
teardown() { teardown_home; }

@test "empty module is valid" {
  mkdir -p "$M/empty"; echo hi > "$M/empty/README.md"
  run module_apply "$M/empty"
  [ "$status" -eq 0 ]
}

@test "config dir links to ~/.config/<name>" {
  mkdir -p "$M/tool/config"; echo x > "$M/tool/config/tool.toml"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.config/tool")" = "$M/tool/config" ]
}

@test "home tree links files into HOME" {
  mkdir -p "$M/tool/home/.ssh"; echo x > "$M/tool/home/.ssh/config"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.ssh/config")" = "$M/tool/home/.ssh/config" ]
}

@test "install.sh runs with env" {
  mkdir -p "$M/tool"; printf '#!/usr/bin/env bash\necho "ran $HOME $DRY_RUN" > "$HOME/ran"\n' > "$M/tool/install.sh"
  chmod +x "$M/tool/install.sh"
  module_apply "$M/tool"
  [ "$(cat "$HOME/ran")" = "ran $HOME 0" ]
}

@test "failing install.sh fails apply" {
  mkdir -p "$M/tool"; printf '#!/usr/bin/env bash\nexit 3\n' > "$M/tool/install.sh"; chmod +x "$M/tool/install.sh"
  run module_apply "$M/tool"
  [ "$status" -ne 0 ]
}

@test "os restriction honoured" {
  mkdir -p "$M/mac"; printf 'os = "macos"\n' > "$M/mac/module.toml"
  mkdir -p "$M/lin"; printf 'os = "linux"\n' > "$M/lin/module.toml"
  mkdir -p "$M/any"
  run module_enabled_for_os "$M/any"; [ "$status" -eq 0 ]
  if [ "$(os_name)" = macos ]; then
    run module_enabled_for_os "$M/mac"; [ "$status" -eq 0 ]
    run module_enabled_for_os "$M/lin"; [ "$status" -ne 0 ]
  else
    run module_enabled_for_os "$M/lin"; [ "$status" -eq 0 ]
    run module_enabled_for_os "$M/mac"; [ "$status" -ne 0 ]
  fi
}

@test "module_brewfiles lists only existing" {
  mkdir -p "$M/a" "$M/b"; echo 'brew "jq"' > "$M/a/Brewfile"
  run module_brewfiles "$M/a" "$M/b"
  [ "$output" = "$M/a/Brewfile" ]
}

@test "module_checklists concatenates" {
  mkdir -p "$M/a" "$M/b"; echo one > "$M/a/CHECKLIST.md"; echo two > "$M/b/CHECKLIST.md"
  run module_checklists "$M/a" "$M/b"
  [ "$output" = $'one\ntwo' ]
}
```

- [ ] **Step 2: Run, expect failure**

Run: `bats tests/module.bats`

- [ ] **Step 3: Implement lib/module.sh**

```bash
#!/usr/bin/env bash
# A module is a folder: Brewfile, config/, home/, install.sh, module.toml, CHECKLIST.md, all optional.

module_enabled_for_os() {
  local toml="$1/module.toml" want
  [ -f "$toml" ] || return 0
  want="$(sed -n 's/^[[:space:]]*os[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$toml" | head -1)"
  [ -z "$want" ] || [ "$want" = "$(os_name)" ]
}

module_apply() {
  local dir="$1" name
  name="$(basename "$dir")"
  log_info "module: $name"
  if [ -d "$dir/config" ]; then
    link_file "$dir/config" "$HOME/.config/$name" || return 1
  fi
  if [ -d "$dir/home" ]; then
    link_tree "$dir/home" "$HOME" || return 1
  fi
  if [ -x "$dir/install.sh" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
      log_dry "run $dir/install.sh"
    else
      DOTFILES_DIR="$DOTFILES_DIR" HOME="$HOME" DRY_RUN="${DRY_RUN:-0}" "$dir/install.sh" ||
        { log_fail "module $name install.sh failed"; return 1; }
    fi
  fi
}

module_brewfiles() {
  local d
  for d in "$@"; do [ -f "$d/Brewfile" ] && echo "$d/Brewfile"; done
  return 0
}

module_checklists() {
  local d
  for d in "$@"; do [ -f "$d/CHECKLIST.md" ] && cat "$d/CHECKLIST.md"; done
  return 0
}
```

- [ ] **Step 4: Write scripts/new-module.sh**

```bash
#!/usr/bin/env bash
# Scaffold modules/<name> with a README. Everything else is optional.
set -euo pipefail
name="${1:?usage: new-module.sh NAME}"
dir="$(cd "$(dirname "$0")/.." && pwd)/modules/$name"
[ -e "$dir" ] && { echo "exists: $dir" >&2; exit 1; }
mkdir -p "$dir"
cat > "$dir/README.md" <<EOF
# $name

What it is, why it is here, and any keybindings worth remembering.

Optional files: Brewfile, config/ (-> ~/.config/$name), home/ (-> ~),
install.sh (idempotent post-link hook), module.toml (os = "macos"|"linux"),
CHECKLIST.md (manual steps printed after install).
EOF
echo "created $dir"
```
Then `chmod +x scripts/new-module.sh`.

- [ ] **Step 5: Run, expect pass**

Run: `bats tests/module.bats`
Expected: 8 pass.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck lib/module.sh scripts/new-module.sh && git add -A && git commit -m "feat: module apply, brewfile and checklist collection, module scaffold"
```

---

### Task 5: Homebrew library

**Files:**
- Create: `lib/brew.sh`, `tests/brew.bats`

**Interfaces:**
- Consumes: `log_*`, `os_name`, `brew_prefix`, `DRY_RUN`.
- Produces: `brew_ensure` (installs Homebrew if `brew` missing, evals shellenv so `brew` is on PATH for the rest of the run), `brew_bundle FILE...` (concatenates Brewfiles to a temp file and runs `brew bundle --file=TMP --no-lock`), `brew_missing FILE...` (prints formula/cask names from the Brewfiles that are not installed; used by doctor).

- [ ] **Step 1: Write failing tests**

Brew itself is not exercised in unit tests; the pure parts are.

`tests/brew.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log os brew; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "brew_concat merges files and drops comments and blanks" {
  printf '# c\nbrew "jq"\n\n' > "$HOME/a"; printf 'cask "ghostty"\nbrew "jq"\n' > "$HOME/b"
  run brew_concat "$HOME/a" "$HOME/b"
  [ "$output" = $'brew "jq"\ncask "ghostty"' ]
}

@test "brew_names extracts formula and cask names" {
  printf 'brew "jq"\ncask "ghostty"\ntap "x/y"\nbrew "koekeishiya/formulae/yabai", args: ["HEAD"]\n' > "$HOME/a"
  run brew_names "$HOME/a"
  [ "$output" = $'jq\nghostty\nyabai' ]
}

@test "brew_bundle in dry run does not call brew" {
  printf 'brew "jq"\n' > "$HOME/a"
  DRY_RUN=1 run brew_bundle "$HOME/a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry]"* ]]
}
```

- [ ] **Step 2: Run, expect failure**

Run: `bats tests/brew.bats`

- [ ] **Step 3: Implement lib/brew.sh**

```bash
#!/usr/bin/env bash
# Homebrew on macOS and Linux. One bundle from all enabled modules' Brewfiles.

brew_ensure() {
  if ! command -v brew >/dev/null 2>&1; then
    if [ -x "$(brew_prefix)/bin/brew" ]; then
      eval "$("$(brew_prefix)/bin/brew" shellenv)"
      return 0
    fi
    if [ "${DRY_RUN:-0}" = 1 ]; then
      log_dry "install homebrew"
      return 0
    fi
    log_info "installing Homebrew"
    if [ "$(os_name)" = linux ]; then
      sudo apt-get update -qq && sudo apt-get install -y -qq build-essential curl file git procps >/dev/null
    fi
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$("$(brew_prefix)/bin/brew" shellenv)"
  fi
  log_ok "homebrew $(brew --version | head -1)"
}

# Merge Brewfiles: drop comments and blank lines, dedupe, keep first order.
brew_concat() {
  cat "$@" | sed 's/[[:space:]]*#.*$//' | grep -v '^[[:space:]]*$' | awk '!seen[$0]++'
}

# Bare names of brew and cask entries, last path component, no args.
brew_names() {
  brew_concat "$@" | sed -n 's/^\(brew\|cask\) "\([^"]*\)".*/\2/p' | sed 's|.*/||'
}

brew_bundle() {
  local tmp
  [ "$#" -gt 0 ] || return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "brew bundle: $(brew_names "$@" | tr '\n' ' ')"
    return 0
  fi
  tmp="$(mktemp)"
  brew_concat "$@" > "$tmp"
  log_info "brew bundle ($(wc -l < "$tmp" | tr -d ' ') entries)"
  brew bundle --file="$tmp" --no-upgrade
  rm -f "$tmp"
}

brew_missing() {
  local installed n
  installed="$(brew list --formula -1 2>/dev/null; brew list --cask -1 2>/dev/null)"
  for n in $(brew_names "$@"); do
    case "$installed" in *"$n"*) ;; *) echo "$n" ;; esac
  done
}
```

Note: macOS `sed` does not support `\|` alternation in basic mode. Use `sed -E -n 's/^(brew|cask) "([^"]*)".*/\2/p'` instead; adjust the line above to the `-E` form before running.

- [ ] **Step 4: Run, expect pass**

Run: `bats tests/brew.bats`
Expected: 3 pass.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck lib/brew.sh && git add -A && git commit -m "feat: homebrew ensure, bundle, missing"
```

---

### Task 6: install.sh with workspace and secrets modules

**Files:**
- Create: `install.sh`, `modules/workspace/install.sh`, `modules/workspace/README.md`, `modules/secrets/install.sh`, `modules/secrets/manifest.txt`, `modules/secrets/README.md`, `tests/install.bats`

**Interfaces:**
- Consumes: everything in `lib/`.
- Produces: `./install.sh [PROFILE] [--dry-run] [--overlay URL]`. Exports `DOTFILES_DIR`. Profile defaults to `recall profile`, then `personal`. Sets `DRY_RUN`. Order: brew_ensure, resolve modules, filter by OS, brew_bundle, apply each, overlay (Task 8), remember profile, print checklists.
- `modules/secrets/manifest.txt` format: `name  purpose` one per line; `secrets_missing` reads it (defined in the module's install.sh and duplicated in doctor via sourcing `lib/secrets.sh`; see step 3).

- [ ] **Step 1: Write module files**

`modules/workspace/install.sh`:
```bash
#!/usr/bin/env bash
# Create the two project roots that git identity switching keys on.
set -euo pipefail
for d in "$HOME/work" "$HOME/personal"; do
  if [ -d "$d" ]; then
    echo "skip $d"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] mkdir $d"
  else
    mkdir -p "$d" && echo "mkdir $d"
  fi
done
```

`modules/workspace/README.md`:
```
# workspace

Creates ~/work and ~/personal. Every repo lives under one of them;
git picks the identity from the path (see modules/git).
```

`lib/secrets.sh`:
```bash
#!/usr/bin/env bash
# ~/.secrets holds one file per secret. Never in any repo.

secrets_dir() { echo "$HOME/.secrets"; }
secrets_manifest() { echo "$DOTFILES_DIR/modules/secrets/manifest.txt"; }

# Prints "name  purpose" for every manifest entry without a file.
secrets_missing() {
  local name rest
  [ -f "$(secrets_manifest)" ] || return 0
  while read -r name rest; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    [ -f "$(secrets_dir)/$name" ] || printf '%s  %s\n' "$name" "$rest"
  done < "$(secrets_manifest)"
}
```

`modules/secrets/install.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../../lib/secrets.sh
source "$DOTFILES_DIR/lib/secrets.sh"
d="$(secrets_dir)"
if [ -d "$d" ]; then
  echo "skip $d"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] mkdir $d (mode 700)"
else
  mkdir -p "$d" && chmod 700 "$d" && echo "mkdir $d"
fi
missing="$(secrets_missing)"
if [ -n "$missing" ]; then
  echo "missing secrets (create files under $d):"
  echo "$missing" | sed 's/^/  /'
fi
```

`modules/secrets/manifest.txt`:
```
# name            purpose (one per line; the file ~/.secrets/<name> holds the value)
github_token      GitHub personal access token for gh and scripts
```

`modules/secrets/README.md`:
```
# secrets

~/.secrets/<name> files, mode 700 directory, never committed anywhere.
manifest.txt lists what is expected; install and doctor report gaps.
Projects read values via direnv (.envrc: export X="$(cat ~/.secrets/x)").
```

- [ ] **Step 2: Write failing tests**

`tests/install.bats`:
```bash
load helper
setup() {
  setup_home
  export DOTFILES_PROFILES="$HOME/profiles"; mkdir -p "$DOTFILES_PROFILES"
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES/one"
  printf 'modules = ["one"]\n' > "$DOTFILES_PROFILES/test.toml"
  export DOTFILES_SKIP_BREW=1
  touch "$HOME/.hushlogin"
}
teardown() { teardown_home; }

@test "dry run applies nothing and remembers nothing" {
  run "$DOTFILES_DIR/install.sh" test --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.config/dotfiles/profile" ]
}

@test "install applies module and remembers profile" {
  mkdir -p "$DOTFILES_MODULES/one/config"; touch "$DOTFILES_MODULES/one/config/x"
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/one" ]
  [ "$(cat "$HOME/.config/dotfiles/profile")" = "test" ]
}

@test "second run is a no-op" {
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/install.sh" test
  [ "$status" -eq 0 ]
  [[ "$output" != *"link "* ]]
  [[ "$output" != *"backup"* ]]
}

@test "profile defaults to remembered then personal" {
  "$DOTFILES_DIR/install.sh" test >/dev/null
  run "$DOTFILES_DIR/install.sh"
  [[ "$output" == *"profile: test"* ]]
}

@test "unknown module in profile fails" {
  printf 'modules = ["ghost"]\n' > "$DOTFILES_PROFILES/bad.toml"
  run "$DOTFILES_DIR/install.sh" bad
  [ "$status" -ne 0 ]
}

@test "workspace and secrets modules create dirs and report manifest" {
  unset DOTFILES_MODULES
  printf 'modules = ["workspace", "secrets"]\n' > "$DOTFILES_PROFILES/ws.toml"
  run "$DOTFILES_DIR/install.sh" ws
  [ "$status" -eq 0 ]
  [ -d "$HOME/work" ] && [ -d "$HOME/personal" ]
  [ "$(stat -f %Lp "$HOME/.secrets" 2>/dev/null || stat -c %a "$HOME/.secrets")" = "700" ]
  [[ "$output" == *"github_token"* ]]
}
```

- [ ] **Step 3: Run, expect failure**

Run: `bats tests/install.bats`

- [ ] **Step 4: Implement install.sh**

```bash
#!/usr/bin/env bash
# Entry point. ./install.sh [PROFILE] [--dry-run] [--overlay URL]
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
for f in log os link profile module brew secrets ssh overlay; do
  [ -f "$DOTFILES_DIR/lib/$f.sh" ] && source "$DOTFILES_DIR/lib/$f.sh"
done

DRY_RUN=0
OVERLAY_URL=""
PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --overlay) OVERLAY_URL="$2"; shift ;;
    -h | --help) sed -n '2p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) PROFILE="$1" ;;
  esac
  shift
done
export DRY_RUN
[ -n "$PROFILE" ] || PROFILE="$(recall profile || true)"
[ -n "$PROFILE" ] || PROFILE=personal
[ -n "$OVERLAY_URL" ] || OVERLAY_URL="$(recall overlay || true)"

os="$(os_name)" || die "unsupported OS: $(uname -s)"
log_info "profile: $PROFILE ($os/$(os_arch))"
[ "$DRY_RUN" = 1 ] && log_warn "dry run: nothing will change"

modules_root="${DOTFILES_MODULES:-$DOTFILES_DIR/modules}"
module_dirs=""
for m in $(profile_modules "$PROFILE"); do
  d="$modules_root/$m"
  [ -d "$d" ] || die "module not found: $m"
  module_enabled_for_os "$d" || { log_info "skip $m (not for $os)"; continue; }
  module_dirs="$module_dirs $d"
done

if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ]; then
  brew_ensure
  # shellcheck disable=SC2086
  brew_bundle $(module_brewfiles $module_dirs)
fi

for d in $module_dirs; do
  module_apply "$d" || die "module failed: $(basename "$d")"
done

if profile_has_overlay "$PROFILE" && type overlay_apply >/dev/null 2>&1; then
  overlay_apply "$OVERLAY_URL"
fi

if [ "$DRY_RUN" != 1 ]; then
  remember profile "$PROFILE"
fi

# shellcheck disable=SC2086
checklist="$(module_checklists $module_dirs)"
if [ -n "$checklist" ]; then
  log_info "manual steps:"
  echo "$checklist"
fi
log_ok "done"
```

`overlay_apply` is defined in Task 8; the `type` guard lets Task 6 pass without it.

- [ ] **Step 5: Run, expect pass**

Run: `chmod +x install.sh modules/*/install.sh && bats tests/install.bats`
Expected: 6 pass.

- [ ] **Step 6: Lint and commit**

```bash
just lint && git add -A && git commit -m "feat: install entry point, workspace and secrets modules"
```

---

### Task 7: git and ssh modules with guided key setup

**Files:**
- Create: `lib/ssh.sh`, `modules/git/home/.gitconfig`, `modules/git/config/ignore`, `modules/git/config/identity.personal`, `modules/git/README.md`, `modules/ssh/home/.ssh/config`, `modules/ssh/install.sh`, `modules/ssh/README.md`, `tests/ssh.bats`, `tests/git.bats`

**Interfaces:**
- Consumes: `log_*`, `is_tty`, `DRY_RUN`, `recall profile`.
- Produces: `ssh_key_path CTX` (prints `$HOME/.ssh/id_ed25519_CTX`), `ssh_ensure_key CTX EMAIL` (generate if missing, interactive only), `ssh_test CTX` (0 if `ssh -T git@github.com-CTX` authenticates), `ssh_contexts_for_profile NAME` (prints `personal`, plus `work` if the profile has an overlay).

- [ ] **Step 1: Write git module files**

`modules/git/home/.gitconfig`:
```ini
# No [user] here on purpose. Identity comes from the directory:
#   ~/personal/** -> identity.personal   ~/work/** -> identity.work
# Committing elsewhere fails, which is the point.
[includeIf "gitdir:~/personal/"]
    path = ~/.config/git/identity.personal
[includeIf "gitdir:~/work/"]
    path = ~/.config/git/identity.work
[core]
    excludesfile = ~/.config/git/ignore
[init]
    defaultBranch = main
[user]
    useConfigOnly = true
```

`modules/git/config/identity.personal`:
```ini
[user]
    name = Anand Panda
    email = PERSONAL_EMAIL_PLACEHOLDER
[url "git@github.com-personal:"]
    insteadOf = git@github.com:
    insteadOf = https://github.com/
```
Ask Anand for the personal email before committing; replace the placeholder.

`modules/git/config/ignore`:
```
.DS_Store
.env
.envrc
.direnv/
*.local
.vscode/*.local.json
```

`modules/git/README.md`:
```
# git

~/.gitconfig with no identity. includeIf picks identity.personal or
identity.work by directory. identity.work comes from the private overlay.
Each identity rewrites github.com to its SSH alias so clones use the
right key without thinking. user.useConfigOnly makes commits outside
~/work and ~/personal fail loudly.
```

- [ ] **Step 2: Write ssh module files**

`modules/ssh/home/.ssh/config`:
```
# Static. Only names key paths; keys are generated per machine by install.
Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_personal
  IdentitiesOnly yes

Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_work
  IdentitiesOnly yes

Host *
  AddKeysToAgent yes
  ServerAliveInterval 60
```

`lib/ssh.sh`:
```bash
#!/usr/bin/env bash
# Guided SSH key setup. Asks only when a key is missing and a terminal is attached.

ssh_key_path() { echo "$HOME/.ssh/id_ed25519_$1"; }

ssh_contexts_for_profile() {
  echo personal
  profile_has_overlay "$1" 2>/dev/null && echo work
  return 0
}

ssh_test() {
  local out
  out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T "git@github.com-$1" 2>&1 || true)"
  case "$out" in *"successfully authenticated"*) return 0 ;; *) return 1 ;; esac
}

ssh_ensure_key() {
  local ctx="$1" email="$2" key
  key="$(ssh_key_path "$ctx")"
  if [ -f "$key" ]; then
    log_ok "ssh key $ctx present"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "generate ssh key $key"
    return 0
  elif ! is_tty; then
    log_warn "no terminal: skipping ssh key generation for $ctx"
    return 0
  else
    printf 'Generate %s ssh key at %s? [Y/n] ' "$ctx" "$key"
    read -r ans
    case "$ans" in n | N) log_warn "skipped $ctx key"; return 0 ;; esac
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
    echo
    echo "Add this public key at https://github.com/settings/keys :"
    echo
    cat "$key.pub"
    echo
    printf 'Press enter once added... '
    read -r _
  fi
  if [ "${DRY_RUN:-0}" != 1 ]; then
    if ssh_test "$ctx"; then log_ok "github.com-$ctx authenticates"; else log_warn "github.com-$ctx does not authenticate yet"; fi
  fi
}
```

`modules/ssh/install.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
for f in log profile ssh; do source "$DOTFILES_DIR/lib/$f.sh"; done
profile="$(recall profile 2>/dev/null || echo "${DOTFILES_PROFILE:-personal}")"
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
for ctx in $(ssh_contexts_for_profile "$profile"); do
  email="${DOTFILES_EMAIL_PERSONAL:-}"
  [ "$ctx" = work ] && email="${DOTFILES_EMAIL_WORK:-}"
  ssh_ensure_key "$ctx" "${email:-$ctx@$(hostname -s)}"
done
```

Note: `install.sh` must export `DOTFILES_PROFILE="$PROFILE"` before applying modules so this hook sees the profile on the first run, before it is remembered. Add `export DOTFILES_PROFILE="$PROFILE"` right after `PROFILE` is resolved in `install.sh`.

`modules/ssh/README.md`:
```
# ssh

~/.ssh/config with github.com-personal and github.com-work aliases.
Keys: ~/.ssh/id_ed25519_personal and _work, generated on first install
when a terminal is attached. Add the printed public key to GitHub.
```

- [ ] **Step 3: Write failing tests**

`tests/ssh.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log profile ssh; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "key path per context" {
  [ "$(ssh_key_path work)" = "$HOME/.ssh/id_ed25519_work" ]
}

@test "contexts: personal only, work adds work" {
  run ssh_contexts_for_profile personal; [ "$output" = "personal" ]
  run ssh_contexts_for_profile work; [ "$output" = $'personal\nwork' ]
}

@test "existing key is reported present, no prompt" {
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/id_ed25519_personal"
  ssh_test() { return 0; }
  run ssh_ensure_key personal a@b
  [[ "$output" == *"present"* ]]
}

@test "missing key without tty warns and skips" {
  run ssh_ensure_key personal a@b
  [ "$status" -eq 0 ]
  [[ "$output" == *"no terminal"* ]]
  [ ! -f "$HOME/.ssh/id_ed25519_personal" ]
}

@test "dry run does not generate" {
  DRY_RUN=1 run ssh_ensure_key personal a@b
  [[ "$output" == *"[dry]"* ]]
}
```

`tests/git.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  module_apply "$DOTFILES_DIR/modules/git" >/dev/null
  mkdir -p "$HOME/.config/git"
  printf '[user]\n  name = W\n  email = w@work\n' > "$HOME/.config/git/identity.work"
  mkdir -p "$HOME/work/r" "$HOME/personal/r" "$HOME/elsewhere/r"
  for d in work personal elsewhere; do git -C "$HOME/$d/r" init -q; done
}
teardown() { teardown_home; }

@test "work tree gets work identity" {
  [ "$(git -C "$HOME/work/r" config user.email)" = "w@work" ]
}

@test "personal tree gets personal identity" {
  run git -C "$HOME/personal/r" config user.email
  [ "$status" -eq 0 ]; [ -n "$output" ]
}

@test "elsewhere has no identity and commit fails" {
  cd "$HOME/elsewhere/r" && touch f && git add f
  run git commit -qm x
  [ "$status" -ne 0 ]
}

@test "personal tree rewrites github urls to personal alias" {
  cd "$HOME/personal/r" && git remote add o git@github.com:x/y.git
  run git -C "$HOME/personal/r" ls-remote --get-url o
  [ "$output" = "git@github.com-personal:x/y.git" ]
}
```

- [ ] **Step 4: Run, expect failure**

Run: `bats tests/ssh.bats tests/git.bats`

- [ ] **Step 5: Add `export DOTFILES_PROFILE` to install.sh, fill personal email, run tests**

Edit `install.sh`: after `[ -n "$PROFILE" ] || PROFILE=personal` add `export DOTFILES_PROFILE="$PROFILE"`.

Run: `chmod +x modules/ssh/install.sh && bats tests/ssh.bats tests/git.bats`
Expected: 9 pass.

- [ ] **Step 6: Lint and commit**

```bash
just lint && git add -A && git commit -m "feat: git identity switching, ssh aliases, guided key setup"
```

---

### Task 8: Overlay library, example, and overlay-init

**Files:**
- Create: `lib/overlay.sh`, `overlays/work.example/README.md`, `overlays/work.example/modules/git/config/identity.work`, `scripts/overlay-init.sh`, `tests/overlay.bats`

**Interfaces:**
- Consumes: `log_*`, `is_tty`, `remember`, `recall`, `module_*`, `brew_bundle`, `DRY_RUN`.
- Produces: `overlay_dir` (prints `$HOME/.dotfiles-work`), `overlay_resolve_url URL` (returns URL if given, else recalled, else prompts if tty, else empty), `overlay_ensure URL` (clone or `git pull --ff-only`), `overlay_apply URL` (resolve, ensure, bundle overlay Brewfiles, apply overlay modules in sorted order, remember url).

- [ ] **Step 1: Write example overlay and scaffold script**

`overlays/work.example/README.md`:
```
# Work overlay (example)

A private repo with this shape, applied by `install.sh work` after the
public modules. Same module rules as the public repo. Typical contents:

modules/
  git/config/identity.work      # name, email, signing key, url rewrite to github.com-work
  claude-work/home/work/CLAUDE.md   # lands at ~/work/CLAUDE.md
  aws/home/.aws/config          # profile names only, no keys
  kube/Brewfile                 # kubectl, k9s, ...

Never commit secret values here either. Use ~/.secrets.
Create a real one with: just overlay-init ~/personal/dotfiles-work
```

`overlays/work.example/modules/git/config/identity.work`:
```ini
[user]
    name = Your Name
    email = you@company.com
[url "git@github.com-work:"]
    insteadOf = git@github.com:
    insteadOf = https://github.com/
```

`scripts/overlay-init.sh`:
```bash
#!/usr/bin/env bash
# Create a private overlay repo skeleton at PATH from overlays/work.example.
set -euo pipefail
dest="${1:?usage: overlay-init.sh PATH}"
src="$(cd "$(dirname "$0")/.." && pwd)/overlays/work.example"
[ -e "$dest" ] && { echo "exists: $dest" >&2; exit 1; }
mkdir -p "$dest"
cp -R "$src/." "$dest/"
git -C "$dest" init -q
git -C "$dest" add -A
git -C "$dest" commit -qm "overlay skeleton"
echo "created $dest"
echo "next: edit modules/git/config/identity.work, push to a private repo,"
echo "      then: just install work <repo-url>"
```

- [ ] **Step 2: Write failing tests**

`tests/overlay.bats`:
```bash
load helper
setup() {
  setup_home
  for f in log os link profile module brew overlay; do source "$DOTFILES_DIR/lib/$f.sh"; done
  export DOTFILES_SKIP_BREW=1
  REMOTE="$HOME/remote"; "$DOTFILES_DIR/scripts/overlay-init.sh" "$REMOTE" >/dev/null
  mkdir -p "$REMOTE/modules/extra/config"; touch "$REMOTE/modules/extra/config/x"
  git -C "$REMOTE" add -A && git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -qm extra
}
teardown() { teardown_home; }

@test "overlay_resolve_url prefers argument, then recall, else empty without tty" {
  [ "$(overlay_resolve_url "u1")" = "u1" ]
  remember overlay "u2"
  [ "$(overlay_resolve_url "")" = "u2" ]
  rm "$HOME/.config/dotfiles/overlay"
  [ -z "$(overlay_resolve_url "")" ]
}

@test "overlay_apply clones, applies modules, remembers url" {
  overlay_apply "$REMOTE"
  [ -d "$HOME/.dotfiles-work/.git" ]
  [ "$(readlink "$HOME/.config/extra")" = "$HOME/.dotfiles-work/modules/extra/config" ]
  [ "$(readlink "$HOME/.config/git")" = "$HOME/.dotfiles-work/modules/git/config" ] || [ -L "$HOME/.config/git" ]
  [ "$(recall overlay)" = "$REMOTE" ]
}

@test "second apply pulls instead of cloning" {
  overlay_apply "$REMOTE"
  run overlay_apply "$REMOTE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull"* ]]
}

@test "no url and no tty warns and returns 0" {
  run overlay_apply ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"no overlay url"* ]]
}

@test "dry run does not clone" {
  DRY_RUN=1 run overlay_apply "$REMOTE"
  [ ! -d "$HOME/.dotfiles-work" ]
}
```

Also add to `tests/install.bats`:
```bash
@test "non-tty skips guided steps" {
  printf 'extends = "test"\noverlay = true\n' > "$DOTFILES_PROFILES/w.toml"
  run "$DOTFILES_DIR/install.sh" w
  [ "$status" -eq 0 ]
  [[ "$output" == *"no overlay url"* ]]
}
```

- [ ] **Step 3: Run, expect failure**

Run: `bats tests/overlay.bats tests/install.bats`

- [ ] **Step 4: Implement lib/overlay.sh**

```bash
#!/usr/bin/env bash
# Private overlay: a second repo with modules/, applied after public modules.

overlay_dir() { echo "$HOME/.dotfiles-work"; }

overlay_resolve_url() {
  local url="$1"
  [ -n "$url" ] || url="$(recall overlay || true)"
  if [ -z "$url" ] && is_tty; then
    printf 'Private overlay repo url (git@github.com:org/repo.git): '
    read -r url
  fi
  echo "$url"
}

overlay_ensure() {
  local url="$1" dir
  dir="$(overlay_dir)"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "clone or pull overlay $url -> $dir"
    return 0
  fi
  if [ -d "$dir/.git" ]; then
    log_info "overlay pull"
    git -C "$dir" pull --ff-only -q
  else
    log_info "overlay clone"
    git clone -q "$url" "$dir"
  fi
}

overlay_apply() {
  local url dir dirs="" d
  url="$(overlay_resolve_url "${1:-}")"
  if [ -z "$url" ]; then
    log_warn "no overlay url: skipping overlay"
    return 0
  fi
  overlay_ensure "$url" || die "overlay fetch failed"
  [ "${DRY_RUN:-0}" = 1 ] && return 0
  dir="$(overlay_dir)"
  for d in "$dir"/modules/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    module_enabled_for_os "$d" || continue
    dirs="$dirs $d"
  done
  if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ]; then
    # shellcheck disable=SC2086
    brew_bundle $(module_brewfiles $dirs)
  fi
  for d in $dirs; do
    module_apply "$d" || die "overlay module failed: $(basename "$d")"
  done
  remember overlay "$url"
  log_ok "overlay applied"
}
```

Note on the git module collision: the public `git` module links `config/` as a whole directory to `~/.config/git`. An overlay `git/config/identity.work` would then replace that link. To let both coexist, change `module_apply` so that when `~/.config/<name>` is already a symlink to another module's `config/`, it links the overlay's files individually into the target directory instead. Implement by replacing the `config` branch in `lib/module.sh` with:

```bash
  if [ -d "$dir/config" ]; then
    local target="$HOME/.config/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" != "$dir/config" ] && [ -d "$(readlink "$target")" ]; then
      # Another module owns this dir: lay our files inside it as individual links.
      link_tree "$dir/config" "$(readlink "$target")" || return 1
    else
      link_file "$dir/config" "$target" || return 1
    fi
  fi
```

This writes a symlink into the public repo's `modules/git/config/` directory. Add `modules/*/config/identity.work` to `.gitignore` so it never gets committed.

- [ ] **Step 5: Run, expect pass**

Run: `chmod +x scripts/overlay-init.sh && bats tests`
Expected: all pass.

- [ ] **Step 6: Lint and commit**

```bash
just lint && git add -A && git commit -m "feat: private overlay apply, example overlay, overlay-init"
```

---

### Task 9: macOS defaults module

**Files:**
- Create: `modules/macos/module.toml`, `modules/macos/install.sh`, `modules/macos/README.md`

**Interfaces:**
- Consumes: `DRY_RUN`.
- Produces: idempotent `defaults write` set; `set_default DOMAIN KEY TYPE VALUE` helper that only writes when the current value differs, so reruns print nothing.

- [ ] **Step 1: Verify each key on this Mac**

For each key below run `defaults read DOMAIN KEY` before and after one manual `defaults write`, and keep only keys that take effect on macOS 26. Drop any that error.

- [ ] **Step 2: Write module files**

`modules/macos/module.toml`:
```toml
os = "macos"
```

`modules/macos/install.sh`:
```bash
#!/usr/bin/env bash
# System defaults. Each line says what it does. Only writes when a value differs.
set -euo pipefail
[ "$(uname -s)" = Darwin ] || exit 0

changed=0
set_default() { # DOMAIN KEY TYPE VALUE
  local cur
  cur="$(defaults read "$1" "$2" 2>/dev/null || echo "__unset__")"
  case "$3" in
    -bool) [ "$cur" = 1 ] && cur=true; [ "$cur" = 0 ] && cur=false ;;
  esac
  [ "$cur" = "$4" ] && return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then echo "[dry] defaults write $1 $2 $3 $4"; return 0; fi
  defaults write "$1" "$2" "$3" "$4"
  echo "set $1 $2 = $4"
  changed=1
}

# Keyboard: fast repeat, short delay, no autocorrect or smart punctuation.
set_default NSGlobalDomain KeyRepeat -int 2
set_default NSGlobalDomain InitialKeyRepeat -int 15
set_default NSGlobalDomain ApplePressAndHoldEnabled -bool false
set_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
set_default NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
set_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
set_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
set_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Trackpad: tap to click.
set_default com.apple.AppleMultitouchTrackpad Clicking -bool true
set_default com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Finder: show extensions, path bar, status bar, list view, no extension-change nag.
set_default NSGlobalDomain AppleShowAllExtensions -bool true
set_default com.apple.finder ShowPathbar -bool true
set_default com.apple.finder ShowStatusBar -bool true
set_default com.apple.finder FXPreferredViewStyle -string Nlsv
set_default com.apple.finder FXEnableExtensionChangeWarning -bool false
set_default com.apple.finder _FXSortFoldersFirst -bool true

# Dock: autohide, no recents, small, fast.
set_default com.apple.dock autohide -bool true
set_default com.apple.dock show-recents -bool false
set_default com.apple.dock tilesize -int 40
set_default com.apple.dock autohide-delay -float 0
set_default com.apple.dock expose-animation-duration -float 0.1

# Screenshots: png into ~/Screenshots, no shadow.
mkdir -p "$HOME/Screenshots"
set_default com.apple.screencapture location -string "$HOME/Screenshots"
set_default com.apple.screencapture type -string png
set_default com.apple.screencapture disable-shadow -bool true

if [ "$changed" = 1 ]; then
  killall Finder Dock SystemUIServer 2>/dev/null || true
  echo "restarted Finder and Dock"
fi
```

`modules/macos/README.md`:
```
# macos

defaults write for keyboard, trackpad, Finder, Dock, screenshots.
Writes only when a value differs, so reruns are silent. Some keys need
a logout to fully apply (KeyRepeat). Linux skips this module.
```

- [ ] **Step 3: Test on this Mac**

Run: `DRY_RUN=1 ./modules/macos/install.sh` and confirm the dry lines look right. Then `./modules/macos/install.sh`, then run it again and confirm no `set` lines print.

- [ ] **Step 4: Lint and commit**

```bash
chmod +x modules/macos/install.sh && just lint && git add -A && git commit -m "feat: macos defaults module"
```

---

### Task 10: doctor.sh

**Files:**
- Create: `doctor.sh`, `tests/doctor.bats`

**Interfaces:**
- Consumes: all libs.
- Produces: `./doctor.sh` read-only report. Sections: profile, overlay, brew missing, links, unmanaged `~/.config` entries, secrets missing. Exit 1 if any problem.

- [ ] **Step 1: Write failing tests**

`tests/doctor.bats`:
```bash
load helper
setup() {
  setup_home
  export DOTFILES_PROFILES="$HOME/profiles"; mkdir -p "$DOTFILES_PROFILES"
  export DOTFILES_MODULES="$HOME/mods"; mkdir -p "$DOTFILES_MODULES/one/config"; touch "$DOTFILES_MODULES/one/config/x"
  printf 'modules = ["one"]\n' > "$DOTFILES_PROFILES/test.toml"
  export DOTFILES_SKIP_BREW=1
  "$DOTFILES_DIR/install.sh" test >/dev/null
}
teardown() { teardown_home; }

@test "clean machine passes" {
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile: test"* ]]
}

@test "missing link is reported" {
  rm "$HOME/.config/one"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing link"*".config/one"* ]]
}

@test "wrong link is reported" {
  rm "$HOME/.config/one"; ln -s /tmp "$HOME/.config/one"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wrong link"* ]]
}

@test "unmanaged config entry is listed as info, not failure" {
  mkdir -p "$HOME/.config/stray"
  run "$DOTFILES_DIR/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmanaged"*"stray"* ]]
}
```

- [ ] **Step 2: Run, expect failure**

Run: `bats tests/doctor.bats`

- [ ] **Step 3: Implement doctor.sh**

```bash
#!/usr/bin/env bash
# Read-only drift report. Exit 1 if anything needs fixing.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
for f in log os link profile module brew secrets overlay; do source "$DOTFILES_DIR/lib/$f.sh"; done

problems=0
problem() { log_fail "$*"; problems=$((problems + 1)); }

profile="$(recall profile || echo personal)"
log_info "profile: $profile"

modules_root="${DOTFILES_MODULES:-$DOTFILES_DIR/modules}"
dirs=""
for m in $(profile_modules "$profile"); do
  d="$modules_root/$m"
  [ -d "$d" ] || { problem "module missing: $m"; continue; }
  module_enabled_for_os "$d" && dirs="$dirs $d"
done
if profile_has_overlay "$profile"; then
  if [ -d "$(overlay_dir)/.git" ]; then
    log_ok "overlay present ($(recall overlay || echo 'url unknown'))"
    for d in "$(overlay_dir)"/modules/*/; do d="${d%/}"; [ -d "$d" ] && module_enabled_for_os "$d" && dirs="$dirs $d"; done
  else
    problem "overlay missing: run install.sh $profile"
  fi
fi

# Links
check_link() { # SRC DST
  if [ ! -L "$2" ]; then problem "missing link $2"
  elif [ "$(readlink "$2")" != "$1" ]; then problem "wrong link $2 -> $(readlink "$2")"
  fi
}
managed=""
for d in $dirs; do
  name="$(basename "$d")"
  if [ -d "$d/config" ]; then
    managed="$managed $name"
    if [ -L "$HOME/.config/$name" ] && [ "$(readlink "$HOME/.config/$name")" != "$d/config" ] && [ -d "$(readlink "$HOME/.config/$name")" ]; then
      while IFS= read -r f; do check_link "$f" "$(readlink "$HOME/.config/$name")/${f#"$d"/config/}"; done < <(find "$d/config" -type f)
    else
      check_link "$d/config" "$HOME/.config/$name"
    fi
  fi
  if [ -d "$d/home" ]; then
    while IFS= read -r f; do check_link "$f" "$HOME/${f#"$d"/home/}"; done < <(find "$d/home" -type f)
  fi
done
[ "$problems" = 0 ] && log_ok "links"

# Unmanaged ~/.config entries (informational)
if [ -d "$HOME/.config" ]; then
  for e in "$HOME/.config"/*; do
    [ -e "$e" ] || continue
    n="$(basename "$e")"
    [ "$n" = dotfiles ] && continue
    case " $managed " in *" $n "*) ;; *) printf 'unmanaged %s\n' "$e" ;; esac
  done
fi

# Brew
if [ "${DOTFILES_SKIP_BREW:-0}" != 1 ] && command -v brew >/dev/null; then
  # shellcheck disable=SC2086
  missing="$(brew_missing $(module_brewfiles $dirs))"
  if [ -n "$missing" ]; then problem "brew missing: $(echo "$missing" | tr '\n' ' ')"; else log_ok "brew"; fi
fi

# Secrets
missing="$(secrets_missing)"
if [ -n "$missing" ]; then log_warn "secrets missing:"; echo "$missing" | sed 's/^/  /'; else log_ok "secrets"; fi

if [ "$problems" = 0 ]; then log_ok "doctor: clean"; exit 0; fi
log_fail "doctor: $problems problem(s)"
exit 1
```

- [ ] **Step 4: Run, expect pass**

Run: `chmod +x doctor.sh && bats tests/doctor.bats`
Expected: 4 pass.

- [ ] **Step 5: Lint and commit**

```bash
just lint && git add -A && git commit -m "feat: doctor drift report"
```

---

### Task 11: bootstrap.sh

**Files:**
- Create: `bootstrap.sh`

**Interfaces:**
- Produces: `curl -fsSL <raw url>/bootstrap.sh | bash -s -- [profile] [overlay-url]`. Installs prerequisites, Homebrew, git, just; clones to `~/.dotfiles`; runs install.

- [ ] **Step 1: Write bootstrap.sh**

```bash
#!/usr/bin/env bash
# Blank machine to installed dotfiles. Safe to pipe to bash.
#   curl -fsSL https://raw.githubusercontent.com/anandpanda/dotfiles/main/bootstrap.sh | bash -s -- [profile] [overlay-url]
set -euo pipefail
profile="${1:-personal}"
overlay="${2:-}"
repo="https://github.com/anandpanda/dotfiles.git"
dest="$HOME/.dotfiles"

case "$(uname -s)" in
  Darwin)
    xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "re-run after Xcode CLT finishes"; exit 1; }
    prefix=/opt/homebrew; [ "$(uname -m)" = x86_64 ] && prefix=/usr/local ;;
  Linux)
    sudo apt-get update -qq && sudo apt-get install -y -qq build-essential curl file git procps >/dev/null
    prefix=/home/linuxbrew/.linuxbrew ;;
  *) echo "unsupported OS" >&2; exit 1 ;;
esac

if [ ! -x "$prefix/bin/brew" ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$prefix/bin/brew" shellenv)"
brew install -q git just

if [ -d "$dest/.git" ]; then git -C "$dest" pull --ff-only -q; else git clone -q "$repo" "$dest"; fi
cd "$dest"
if [ -n "$overlay" ]; then ./install.sh "$profile" --overlay "$overlay"; else ./install.sh "$profile"; fi
```

Note: the public clone uses HTTPS so no key is needed yet. After install, the personal identity's `insteadOf` only applies inside `~/personal`, so `~/.dotfiles` keeps working over HTTPS. Later phases may move the repo under `~/personal`.

- [ ] **Step 2: Syntax check and dry read**

Run: `bash -n bootstrap.sh && shellcheck bootstrap.sh`

- [ ] **Step 3: Commit**

```bash
chmod +x bootstrap.sh && git add -A && git commit -m "feat: bootstrap one-liner"
```

---

### Task 12: CI, README, full local verification

**Files:**
- Create: `.github/workflows/ci.yml`, `README.md`

- [ ] **Step 1: Write CI**

`.github/workflows/ci.yml`:
```yaml
name: ci
on: [push, pull_request]
jobs:
  lint-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y -qq shellcheck bats
      - run: curl -sS https://webi.sh/shfmt | sh && echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - run: shellcheck install.sh doctor.sh bootstrap.sh lib/*.sh scripts/*.sh modules/*/install.sh
      - run: shfmt -i 2 -ci -d install.sh doctor.sh bootstrap.sh lib scripts modules
      - run: bats tests
  install:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - run: ./install.sh personal
      - run: ./install.sh personal | tee second.log && ! grep -E '^(link|backup) ' second.log
      - run: ./doctor.sh
```

- [ ] **Step 2: Write README.md**

```
# dotfiles

My complete dev environment for macOS and Linux. One command on a blank
machine, tested in CI on both.

    curl -fsSL https://raw.githubusercontent.com/anandpanda/dotfiles/main/bootstrap.sh | bash -s -- personal

Day to day:

    just install [personal|work] [--overlay url] [--dry-run]
    just update        # pull and reinstall with remembered profile
    just doctor        # what drifted
    just lint / unit / test

## How it is built

- modules/<tool>/: one folder per tool. Brewfile, config/ (-> ~/.config/<tool>),
  home/ (-> ~), install.sh, module.toml (os restriction), CHECKLIST.md.
- profiles/<name>.toml: which modules. work extends personal and adds the overlay.
- overlay: a private repo with the same modules/ shape for work-only config.
  Its url is given once and remembered per machine; it is never in this repo.
- ~/.secrets/: secret values, one file each, never in any repo.
- git identity is picked by directory: ~/personal vs ~/work.

See docs/specs for design notes per phase.
```

- [ ] **Step 3: Full local verification on this Mac**

```bash
just lint
just unit
just install personal --dry-run
```
Review the dry run output together with Anand before the real run. Then:
```bash
just install personal
just doctor
just install personal   # expect no link/backup lines
just test               # docker ubuntu smoke test
```

- [ ] **Step 4: Commit and push branch**

```bash
git add -A && git commit -m "feat: ci workflow and readme"
git push -u origin v2
```
Confirm CI is green on GitHub before replacing `main`. Replacing `main` is a separate decision for Anand.

---

## Self-review notes

- Spec coverage: layout (T1), profiles (T3), installer (T6), guided setup (T7, T8), overlay and overlay-init (T8), modules workspace/secrets/git/ssh/macos (T6, T7, T9), doctor (T10), bootstrap (T11), CI and testing (T12). `just module` (T4). All covered.
- Review Focus items 1 and 2 are in T2 tests, 3 in T3, 4 in T4, 5 in T8's addition to `tests/install.bats`.
- Type consistency: `module_apply DIR`, `module_brewfiles DIR...`, `profile_modules NAME`, `recall KEY`, `overlay_apply URL`, `secrets_missing` are used with the same signatures throughout.
- Known wrinkle: the git/overlay `config/` collision handling in T8 writes a symlink into the public checkout; `.gitignore` covers it. Acceptable for Phase 1; revisit if more modules collide.
