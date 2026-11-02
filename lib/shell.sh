#!/usr/bin/env bash
# The line that makes a bash or sh startup file load the shared environment.

shell_env_line() { printf '%s\n' ". \"\$HOME/.config/shell/env.sh\""; }
