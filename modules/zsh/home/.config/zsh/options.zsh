# Generated files never live in the repo: cache for rebuildable, state for history.
export ZSH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
[[ -d $ZSH_CACHE && -d $ZSH_STATE ]] || mkdir -p "$ZSH_CACHE" "$ZSH_STATE"

# History: large, deduped, written as you go. atuin owns Ctrl-R search.
HISTFILE="$ZSH_STATE/history"
HISTSIZE=100000
SAVEHIST=100000
setopt append_history inc_append_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# Navigation and comfort
setopt auto_cd auto_pushd pushd_ignore_dups no_beep interactive_comments

# Completion behaviour (fzf-tab renders the menu)
zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always $realpath'

# Keys: emacs mode. Ctrl-a/e line ends, Alt-arrows word moves, Home/End.
bindkey -e
bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

export EDITOR="code --wait"
export VISUAL="$EDITOR"
export LANG="${LANG:-en_US.UTF-8}"

# zcache NAME CMD...: eval the output of CMD, cached in $ZSH_CACHE until the
# binary behind it changes. Saves a process spawn per tool per shell.
# Set ZCACHE_FILTER to a sed expression to post-process the output once at generation.
# The cache is keyed on the resolved binary path (which changes on upgrade), the
# full command, and the filter; it is written atomically.
zcache() {
  local name="$1" bin="$2" out="$ZSH_CACHE/init-$1.zsh"
  shift
  local binpath="${commands[$bin]:-}"
  if [[ -z $binpath ]]; then return 0; fi
  local sig="# ${binpath:A}|$*|${ZCACHE_FILTER:-}"
  local first=""
  [[ -s $out ]] && IFS= read -r first <"$out"
  if [[ $first != "$sig" ]]; then
    local tmp="$out.$$"
    { print -r -- "$sig"; "$@" 2>/dev/null | sed -e "${ZCACHE_FILTER:-}"; } >|"$tmp"
    if (( pipestatus[1] != 0 )); then command rm -f "$tmp"; return 1; fi
    command mv -f "$tmp" "$out"
  fi
  source "$out"
}
