# mise

One tool for every runtime. Global defaults in config.toml (node lts, python,
go, uv, pnpm); a project pins its own with `mise use node@22` (writes mise.toml)
or the files it already has (.nvmrc, .python-version, go.mod). Missing versions
install on cd. `mise ls` shows what is active, `mise up` upgrades.

Per-project env lives in mise.toml `[env]`; `.env` via `_.file`; machine-only
values in mise.local.toml (gitignored). Secrets stay in ~/.secrets and are read
in, never pasted:

    # mise.local.toml
    [env]
    GITHUB_TOKEN = "{{ read_file('~/.secrets/github_token') }}"

Python: `uv init`, `uv add`, `uv run`; the .venv activates itself. Node: pnpm.
