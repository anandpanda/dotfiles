# Runtimes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** mise owns Node, Python, Go, uv and pnpm with per-project pinning and env; Docker Desktop (macOS) / docker engine (Linux) plus lazydocker; doctor flags Homebrew-owned runtimes.

**Architecture:** Two modules, `mise` and `docker`. mise config under `config/` (→ `~/.config/mise`), activation via the `zcache` helper. Docker: per-OS Brewfiles, Linux engine via Docker's apt repo in `install.sh`, lazydocker config under `home/.config/lazydocker`.

**Spec:** `docs/specs/05-runtimes.md`

## Global Constraints
All earlier. Tests use a fake `mise`/`brew`/`docker` on PATH; never install real runtimes in tests. Network-dependent checks skip.

## Review Focus
1. `mise activate` output cached by `zcache` must be regenerated when mise upgrades (binary path changes): covered by the zcache test; here just assert the hook uses zcache.
2. A project with `.nvmrc` and no mise.toml resolves node through mise (requires the idiomatic setting) — test with `mise config` on a temp project, skip offline.
3. Doctor's brew-owned check must not flag `python@3.x` that another formula depends on without saying so — list them as "brew-owned (dependency)" vs removable; the test checks the removable list only.
4. docker doctor: Desktop closed is a warning not a failure.
5. Linux docker install: idempotent on rerun (repo file exists, user already in group).

### Task 1: mise module
Files: `modules/mise/{Brewfile,config/config.toml,shell.zsh,install.sh,doctor.sh,README.md,CHECKLIST.md}`, `tests/mise.bats`.
- Tests (RED): config parses via `mise config ls` with HOME (skip if no mise); config lists node lts, python, go, uv, pnpm; settings keys present; shell.zsh parses and uses zcache; install.sh with fake mise runs `mise install` once when `mise ls --missing` reports missing and prints skip when not; dry run; doctor with fake brew lists removable brew-owned runtimes (node go pyenv poetry direnv python@* not depended on) and exit 0 (warning), fails if `mise doctor` fails.
- Implement per spec. `just update` adds `mise up`.
- Commit.

### Task 2: docker module
Files: `modules/docker/{Brewfile,Brewfile.macos,Brewfile.linux,install.sh,doctor.sh,shell.zsh,home/.config/lazydocker/config.yml,README.md,CHECKLIST.macos.md}`, `tests/docker.bats`.
- Tests: Brewfiles name docker-desktop (macos) / docker + docker-compose (linux) / lazydocker; lazydocker config links; shell.zsh parses; install.sh on macOS is a no-op; on Linux with fake apt-get/usermod runs the repo setup once and skips when `/etc/apt/sources.list.d/docker.list` exists; doctor: fake docker that fails `info` → exit 0 with warning.
- Commit.

### Task 3: profile, install, verify, cleanup, docs
- `personal.toml` adds `mise`, `docker`. Dry run, real install. `mise which node/python/go/uv/pnpm`. Startup budget still passes. `dots doctor` lists brew-owned runtimes; with Anand, `brew uninstall` them (node python@3.12/13/14 go pyenv poetry direnv) after confirming mise versions work. Docker Desktop running: `docker ps`, `ld`. CI + container. STATUS. Commit.
