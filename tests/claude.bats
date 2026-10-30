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

@test "resolver names an existing owner file for every rule heading" {
  f="$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  n=$(grep -c '^## ' "$f"); [ "$n" -ge 6 ]
  while IFS= read -r h; do
    row=$(grep -F "| ${h#\#\# } |" "$DOTFILES_DIR/$C/RESOLVER.md") || { echo "no owner: $h"; return 1; }
    owners=$(printf '%s\n' "$row" | grep -oE '`[^`]+`' | tr -d '`')
    [ -n "$owners" ] || { echo "no owner file: $h"; return 1; }
    for o in $owners; do [ -f "$DOTFILES_DIR/$C/$o" ] || { echo "missing owner $o for $h"; return 1; }; done
  done < <(grep '^## ' "$f")
}

@test "claude is in personal and server profiles" {
  grep -qF '"claude"' "$DOTFILES_DIR/profiles/personal.toml"
  grep -qF '"claude"' "$DOTFILES_DIR/profiles/server.toml"
  unset DOTFILES_PROFILES
  run profile_modules personal
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx claude
  run profile_modules server
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx claude
}

@test "learning mode triggers have one home" {
  grep -qF '"teach", "with me", "guide me" or "together"' "$DOTFILES_DIR/$C/home/.claude/CLAUDE.md"
  run grep -nE '"teach"|"guide me"|"explain"' "$DOTFILES_DIR/$C/home/.claude/rules/anand.md"
  [ "$status" -eq 1 ]
}
