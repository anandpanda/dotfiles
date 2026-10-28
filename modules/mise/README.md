# mise

One tool for every runtime. Global defaults in config.toml (node lts, python,
go, uv, pnpm); a project pins its own with `mise use node@22` (writes mise.toml)
or the files it already has (.nvmrc, .python-version, go.mod). A pinned version
that is missing installs the first time you run its command. `mise ls` shows
what is active, `mise up` upgrades (old versions are kept: venvs point at them),
`mise run <task>` runs a task from mise.toml, `mise exec -- cmd` runs with the
project's tools without activating.

~/.config/mise links into this repo, so `mise use -g` and `mise settings set`
edit the tracked config.toml: review and commit after.

Per-project env lives in mise.toml `[env]`; `.env` via `_.file`; machine-only
values in mise.local.toml (gitignored globally). Secrets stay in ~/.secrets and
are read in, never pasted:

    [env]
    GITHUB_TOKEN = "{{ read_file(path=env.HOME ~ '/.secrets/github_token') | trim }}"

Python: `uv init`, `uv add`, `uv run`; with a uv.lock the .venv is created and
activated on cd. Node: pnpm.
