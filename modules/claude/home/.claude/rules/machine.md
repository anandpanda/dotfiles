# This machine

- Tools are owned by the dotfiles: add a new tool to the right module's Brewfile and run `dots install`, never a one-off `brew install`.
- Runtimes (node, python, go) come from mise; projects pin their own versions. Never install a runtime with Homebrew.
- Python packages go through uv in the project's venv; never bare `pip install` or `npm install -g`.
- Check the machine with `dots doctor`; change it only through the dotfiles.
- My personal secrets (prod and dev credentials I use for debugging, tool tokens, recovery codes) live outside every repo in `~/.secrets/secrets.yaml` (sops + age), named `<ENV>_<SYSTEM>_<WHAT>`. They are not the apps' secrets: apps use their own `.env` and the team's secret stores. You cannot read the file. Run anything that needs one of mine as `with-secrets NAME... -- '<command>'`, naming only the secrets that command needs, and never print a value.
