load helper
C="modules/claude"
setup() { setup_home; for f in log os link module profile; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "claude module links CLAUDE.md and rules" {
  module_apply "$DOTFILES_DIR/$C" >/dev/null
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md" ]
  for r in anand writing evidence building; do
    [ "$(readlink "$HOME/.claude/rules/$r.md")" = "$DOTFILES_DIR/$C/home/.claude/rules/$r.md" ]
  done
}

@test "CLAUDE.md stays short" {
  n=$(wc -l < "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"); [ "$n" -le 45 ]
}

@test "working agreement carries the agreed rules" {
  f="$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  for p in "literal question" "UNVERIFIED" "stands because" "not a go" "small reversible" \
    "No comments in code" "AI slop" "Do not overcorrect" "outrank plugin skills"; do
    grep -qF "$p" "$f" || { echo "missing: $p"; return 1; }
  done
}

@test "no company data in the public module" {
  run grep -rniE 'work|backend|@[a-z0-9-]+\.(ai|com)' "$DOTFILES_DIR/$C"
  [ "$status" -eq 1 ]
}

@test "resolver names an owner for every rule heading" {
  f="$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  n=$(grep -c '^## ' "$f"); [ "$n" -ge 6 ]
  while IFS= read -r h; do
    grep -qF "${h#\#\# }" "$DOTFILES_DIR/$C/RESOLVER.md" || { echo "no owner: $h"; return 1; }
  done < <(grep '^## ' "$f")
}

@test "claude is in personal and server profiles" {
  unset DOTFILES_PROFILES
  run profile_modules personal; [[ "$output" == *claude* ]]
  run profile_modules server; [[ "$output" == *claude* ]]
}
