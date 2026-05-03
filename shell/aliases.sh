# Portable shell aliases — sourced from .zshrc / .zshrc.local / .bashrc.
# All aliases use `command -v` guards so missing tools degrade silently.

# =============================================================================
# Modern CLI stack — only activates if tool is installed
# =============================================================================

# bat: syntax-highlighted cat
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias preview='bat --style=numbers --color=always'
fi

# eza: modern ls with colors + git integration
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --color=auto'
    alias ll='eza -lah --git'
    alias la='eza -lah'
    alias tree='eza --tree --level=3'
fi

# fd: faster find
if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# dust: tree-style du
if command -v dust >/dev/null 2>&1; then
    alias du='dust'
fi

# duf: pretty df
if command -v duf >/dev/null 2>&1; then
    alias df='duf'
fi

# btop: modern top
if command -v btop >/dev/null 2>&1; then
    alias top='btop'
fi

# Note: grep NOT aliased to rg — different syntax can break scripts.
# Use `rg` directly when you want fast, gitignore-aware search.

# =============================================================================
# Universal navigation
# =============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# =============================================================================
# File safety — interactive + verbose
# =============================================================================

alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
# rm: deliberately NOT aliased — Claude Code's pre-tool-use hook handles
# dangerous patterns (rm -rf, etc.); per-file rm shouldn't prompt every time.

# =============================================================================
# Quality of life
# =============================================================================

alias path='echo -e ${PATH//:/\n}'
alias reload='source ~/.zshrc'
alias cls='clear'

# =============================================================================
# Universal functions
# =============================================================================

# mkcd: make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}
