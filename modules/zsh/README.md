# zsh

Everything lives in ~/.config/zsh (ZDOTDIR), set by the one file in ~: .zshenv.
~/.config/zsh is a real directory (files linked one by one) so rc.d/ and local.zsh
live there without touching the repo. Generated files go to ~/.cache/zsh and ~/.local/state/zsh.
- .zshrc: options → brew → antidote plugins → completion → rc.d/*.zsh (other modules) → aliases → local.zsh
- .zsh_plugins.txt: four plugins, pinned to tags. Edit, open a new shell, antidote rebuilds.
- local.zsh: machine-only tweaks, gitignored, optional.
Login shell is Homebrew's zsh; preflight switches it once (asks for your password).
