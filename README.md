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

- `modules/<tool>/`: one folder per tool. `Brewfile`, `config/` (-> `~/.config/<tool>`),
  `home/` (-> `~`), `install.sh`, `module.toml` (os restriction), `CHECKLIST.md`.
- `profiles/<name>.toml`: which modules. `work` extends `personal` and adds the overlay.
- overlay: a private repo with the same `modules/` shape for work-only config.
  Its url is given once and remembered per machine; it is never in this repo.
- `~/.secrets/`: secret values, one file each, never in any repo.
- git identity is picked by directory: `~/personal` vs `~/work`.

See `docs/specs` for design notes per phase.
