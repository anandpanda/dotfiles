# This machine

- Tools are owned by the dotfiles: add a new tool to the right module's Brewfile and run `dots install`, never a one-off `brew install`.
- Runtimes (node, python, go) come from mise; projects pin their own versions. Never install a runtime with Homebrew.
- Python packages go through uv in the project's venv; never bare `pip install` or `npm install -g`.
- Check the machine with `dots doctor`; change it only through the dotfiles.
