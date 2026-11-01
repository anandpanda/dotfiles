#!/usr/bin/env bash
# ~/.gitconfig is the machine's own file; its first line includes the repo's git config.
# Identity comes from the folder and keys from the ssh config, never from the environment.

git_env_clear() { unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_SSH_COMMAND; }

gitconfig_include_line() { echo '[include] path = ~/.config/git/base.gitconfig'; }

# Git takes the first matching url rewrite and the last value of a single-valued key, so
# with our include first our rewrites win and what other tools append below stays in force.
gitconfig_ensure_include() {
  local cfg="$HOME/.gitconfig" line tmp
  line="$(gitconfig_include_line)"
  if [ ! -L "$cfg" ] && [ -f "$cfg" ] && [ "$(head -1 "$cfg")" = "$line" ]; then
    echo "skip $cfg"
    return 0
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "write $cfg"
    return 0
  fi
  [ ! -L "$cfg" ] || backup_move "$cfg"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$line"
    [ ! -f "$cfg" ] || cat "$cfg"
  } >"$tmp"
  cat "$tmp" >"$cfg" && rm -f "$tmp"
  echo "wrote $cfg"
}

# Runs git ARGS in a throwaway repo inside FOLDER, so that folder's includeIf rules apply.
git_in_folder() { # FOLDER ARGS...
  local probe rc=0
  probe="$(mktemp -d "$1/.dots-probe.XXXXXX")"
  shift
  git -C "$probe" init -q
  git -C "$probe" "$@" || rc=$?
  rm -rf "$probe"
  return "$rc"
}

# The effective signing key file in FOLDER, with ~ expanded; empty when none is set.
git_signing_key_in() { # FOLDER
  local key
  key="$(git_in_folder "$1" config user.signingkey || true)"
  echo "${key/#\~/$HOME}"
}

# "type base64" of a signing key file, whether it names the public or the private key.
git_public_key() { # KEY_FILE
  if head -1 "$1" | grep -q '^-----BEGIN'; then
    ssh-keygen -y -f "$1" | cut -d' ' -f1,2
  else
    cut -d' ' -f1,2 "$1"
  fi
}
