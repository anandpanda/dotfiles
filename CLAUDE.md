# Dotfiles

- Tests run on macOS's bash 3.2, where a failing `[[ ]]` or `(( ))` fails a bats test only on its last line. End every other such check with `|| false`. See https://bats-core.readthedocs.io/en/stable/gotchas.html.
- The repo owns only files no other tool writes. When a tool also writes a file (VS Code's `settings.json`), the repo owns its keys and install merges them into the machine's file.
- Everything under `modules/claude` is general and public: no company, product, repo or person names. Stack guidance lives in each repo's own `CLAUDE.md`.
