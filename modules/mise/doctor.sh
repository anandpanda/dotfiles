#!/usr/bin/env bash
# mise problems (fail), activation (warn: doctor may run from a non-activated shell),
# global tools present, and a warning for runtimes something other than mise provides.
set -euo pipefail
rc=0
if command -v mise >/dev/null 2>&1; then
  report="$(mise doctor --json 2>/dev/null || echo '{}')"
  python3 - "$report" <<'PY' || rc=1
import json, sys
d = json.loads(sys.argv[1] or "{}")
if not d.get("activated", True):
    print("warn: mise not activated in this shell (fine from a script; open a new terminal)")
probs = d.get("problems") or []
for p in probs:
    print("mise problem: %s" % p)
sys.exit(1 if probs else 0)
PY
  missing="$(mise ls --global --missing 2>/dev/null | grep -v '^$' || true)"
  [ -z "$missing" ] || echo "mise tools missing: $(echo "$missing" | tr '\n' ' ') (dots install)"
fi
if command -v brew >/dev/null 2>&1; then
  owned=""
  while IFS= read -r f; do
    case "$f" in
      node | node@* | go | go@* | python | python@* | pyenv | poetry | direnv | uv | pnpm | nvm | asdf)
        # A formula another formula depends on is plumbing, not a runtime of ours: ignore it.
        [ -n "$(brew uses --installed "$f" 2>/dev/null)" ] || owned="$owned $f"
        ;;
    esac
  done < <(brew list --formula 2>/dev/null)
  [ -z "$owned" ] || echo "warn: brew-owned runtimes, mise should own these:$owned (brew uninstall when mise versions work)"
fi
# macOS /etc/paths.d: installers drop files here that outlive what they pointed at.
pd="${DOTFILES_PATHS_D:-/etc/paths.d}"
if [ -d "$pd" ]; then
  for f in "$pd"/*; do
    [ -f "$f" ] || continue
    while IFS= read -r dir; do
      [ -n "$dir" ] && [ ! -d "$dir" ] && echo "warn: stale PATH entry $dir from $f (sudo rm $f)"
    done <"$f"
  done
fi
godev="${DOTFILES_GO_DEV:-/usr/local/go}"
[ -x "$godev/bin/go" ] && echo "warn: Go from go.dev at $godev shadows mise's go; remove it (sudo rm -rf $godev)"
exit $rc
