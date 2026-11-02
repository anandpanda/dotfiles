# shell

The environment every shell shares, defined once in `config/env.sh` (plain sh):
Homebrew's variables and the PATH order `~/.local/bin`, mise shims, Homebrew,
then the rest. zsh reads it from `.zshenv` and `.zprofile`; bash and sh read it
from the first line of `~/.profile` and `~/.bashrc`, which stay the machine's
own files. Claude Code's Bash tool runs it before each command through
`CLAUDE_ENV_FILE` (this module's `claude-settings.json`). So a terminal, an
editor, Claude Code or a script finds the same tools whichever shell starts it.
