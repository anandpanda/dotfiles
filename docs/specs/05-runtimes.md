# Phase 5: Runtimes and project tooling

Date: 2026-10-28
Status: approved by Anand (picks closed in conversation)

## Purpose

Language runtimes pinned per project, one tool owning all of them, per-project
environment and secrets without a second hook, modern package managers, and
containers. Homebrew stops owning languages.

## Picks (closed)

| Slot | Pick | Why | Runner-up |
|------|------|-----|-----------|
| Version manager | mise | single binary, reads .nvmrc/.python-version/.tool-versions, ~10ms, tasks + env built in | asdf |
| Per-project env + secrets | mise `[env]`, `.env`, `mise.local.toml` | direnv + mise is unsupported upstream (hooks fight); one hook | direnv |
| Python | uv (via mise) | replaces pip/venv/pyenv/poetry, 10-100x faster, manages interpreters | poetry |
| Node packages | pnpm (via mise) | fastest warm, strict deps, monorepos; corepack gone from Node 25+ | bun |
| Containers (macOS) | Docker Desktop + lazydocker | GUI Anand wants, licence clean for work | OrbStack if the company pays |
| Containers (Linux) | docker engine + compose + lazydocker | | |

Dropped from this Mac: pyenv, poetry, Homebrew node/python@3.12/go, direnv.
mise, uv and pnpm provide them.

## Modules

**mise**
- `Brewfile`: mise. `config/config.toml` (-> ~/.config/mise/config.toml):
  global tools `node = "lts"`, `python = "latest"`, `go = "latest"`, `uv =
  "latest"`, `pnpm = "latest"`; settings: `experimental = false`,
  `idiomatic_version_file_enable_tools = ["node", "python", "go"]` (honour
  .nvmrc/.python-version/go.mod), `python.uv_venv_auto = true`, `not_found_auto_install = true`.
- `shell.zsh`: `zcache mise mise activate zsh`. No direnv anywhere.
- `install.sh`: `mise install` for the global tools (idempotent, prints skip when
  all present). Dry run prints.
- `doctor.sh`: `mise doctor` exit; each global tool installed; warns when brew
  owns node/python@*/go/pyenv/poetry/direnv (`brew list --formula`).
- `README.md`: the five commands (`mise use node@22` in a project, `mise ls`,
  `mise up`, `mise run`, `mise exec`), and the secrets pattern:
  `mise.local.toml` with `[env] X = "{{ read_file('~/.secrets/x') }}"`.
- `CHECKLIST.md`: open a new terminal; `brew uninstall` the dropped formulae
  (listed) once mise has them.

**docker**
- `Brewfile.macos`: cask docker-desktop; `Brewfile.linux`: docker, docker-compose
  (brew on Linux provides the client; engine via apt in `install.sh` when
  apt exists, else checklist). `Brewfile`: lazydocker.
- `install.sh` (Linux): Docker's apt repo, add user to docker group, idempotent.
- `doctor.sh`: `docker info` reachable (warn, not fail: Desktop may be closed).
- `config/`: lazydocker config.yml, Catppuccin-ish colours (`home/.config/lazydocker`).
- `shell.zsh`: `alias ld=lazydocker`.
- `CHECKLIST.macos.md`: open Docker Desktop once, accept the terms.

## Version policy

mise global tools float on `latest`/`lts` and move on `mise up`; projects pin
their own in `mise.toml` or the idiomatic files. `just update` runs `mise up`.

## Testing

- config parses (`mise config ls` with HOME set); `install.sh` with a fake
  `mise` installs only missing tools and is a no-op on rerun; doctor warns on
  brew-owned runtimes with a fake `brew`; shell.zsh parses; a temp project with
  `.nvmrc` resolves node via `mise which node` (skip without network).
- On this Mac: `node --version`, `python --version`, `go version`, `uv`, `pnpm`
  all resolve through mise (`mise which`), shell startup still under budget,
  `docker ps` works with Desktop running, `ld` opens.

## Out of scope

Project templates, Kubernetes tooling (overlay, later), bun, Ruby/Rust.
