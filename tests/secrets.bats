load helper
S="modules/secrets"
setup() {
  setup_home
  for f in log os link module secrets; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
}
teardown() { teardown_home; }

fake_age_keygen() {
  cat > "$HOME/bin/age-keygen" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  -y) echo "age1fakepublickey" ;;
  -o) printf '# created: now\n# public key: age1fakepublickey\nAGE-SECRET-KEY-1FAKE\n' > "$2" ;;
esac
FAKE
  chmod +x "$HOME/bin/age-keygen"
}
fake_sops() { # KEYS-PRESENT (space separated)
  cat > "$HOME/bin/sops" <<FAKE
#!/usr/bin/env bash
# sops -d --extract '["KEY"]' FILE -> 0 when KEY is one of: $1
k="\$(printf '%s' "\$3" | tr -d '[]"')"
for p in $1; do [ "\$p" = "\$k" ] && exit 0; done
exit 1
FAKE
  chmod +x "$HOME/bin/sops"
}

@test "secrets Brewfile installs age and sops; manifest lists key names" {
  grep -q '^brew "age"' "$DOTFILES_DIR/$S/Brewfile"; grep -q '^brew "sops"' "$DOTFILES_DIR/$S/Brewfile"
  grep -qE '^GITHUB_TOKEN ' "$DOTFILES_DIR/$S/manifest.txt"
}

@test "install creates the dir, generates the age key once, writes the sops config, and is idempotent" {
  fake_age_keygen
  run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ "$(stat -c %a "$HOME/.secrets" 2>/dev/null || stat -f %Lp "$HOME/.secrets")" = "700" ]
  [ -f "$HOME/.secrets/age.key" ]; [ "$(stat -c %a "$HOME/.secrets/age.key" 2>/dev/null || stat -f %Lp "$HOME/.secrets/age.key")" = "600" ]
  [[ "$output" == *"back it up"* ]]
  grep -q "age: age1fakepublickey" "$HOME/.secrets/.sops.yaml"
  [[ "$output" == *"GITHUB_TOKEN"* ]]   # no secrets.yaml yet: every manifest key is missing
  run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [[ "$output" == *"skip"*"age.key"* ]]; [[ "$output" != *"back it up"* ]]
}

@test "dry run creates nothing" {
  fake_age_keygen
  DRY_RUN=1 run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ ! -e "$HOME/.secrets/age.key" ]; [ ! -e "$HOME/.secrets/.sops.yaml" ]
}

@test "without age installed, install still creates the dir and says what to do" {
  run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ -d "$HOME/.secrets" ]; [[ "$output" == *"age not installed"* ]]
}

@test "secrets_missing checks keys inside secrets.yaml through sops" {
  mkdir -p "$HOME/.secrets"; touch "$HOME/.secrets/secrets.yaml"
  fake_sops "GITHUB_TOKEN"
  [ -z "$(secrets_missing)" ]
  fake_sops "OTHER"
  [[ "$(secrets_missing)" == *"GITHUB_TOKEN"* ]]
}

@test "shell.zsh points sops at the key and parses" {
  zsh -n "$DOTFILES_DIR/$S/shell.zsh"
  grep -q 'SOPS_AGE_KEY_FILE' "$DOTFILES_DIR/$S/shell.zsh"
  run zsh -c "source '$DOTFILES_DIR/$S/shell.zsh'; print -r -- \$SOPS_AGE_KEY_FILE"
  [ "$output" = "$HOME/.secrets/age.key" ]
}
