#!/usr/bin/env bash
# mise healthy (problem), global tools present, and a warning for runtimes Homebrew still
# owns: mise should own them. Formulae other formulae depend on are listed but marked.
set -euo pipefail
rc=0
if command -v mise >/dev/null 2>&1; then
  mise doctor >/dev/null 2>&1 || {
    echo "mise doctor reports problems: run 'mise doctor'"
    rc=1
  }
  missing="$(mise ls --missing 2>/dev/null | grep -v '^$' || true)"
  [ -z "$missing" ] || echo "mise tools missing: $(echo "$missing" | tr '\n' ' ') (dots install)"
fi
if command -v brew >/dev/null 2>&1; then
  owned=""
  while IFS= read -r f; do
    case "$f" in
      node | go | pyenv | poetry | direnv | python@*)
        if [ -n "$(brew uses --installed "$f" 2>/dev/null)" ]; then
          owned="$owned $f (dependency, leave it)"
        else
          owned="$owned $f"
        fi
        ;;
    esac
  done < <(brew list --formula 2>/dev/null)
  [ -z "$owned" ] || echo "warn: brew-owned runtimes, mise should own these:$owned (brew uninstall when mise versions work)"
fi
exit $rc
