load helper
S="modules/secrets"
setup() {
  setup_home
  for f in log os link module secrets; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
  # The shipped manifest is empty; tests use their own.
  export DOTFILES_SECRETS_MANIFEST="$HOME/manifest.txt"; printf 'GITHUB_TOKEN  for tests\n' > "$DOTFILES_SECRETS_MANIFEST"
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

@test "secrets Brewfile installs age and sops; the shipped manifest has no entries" {
  grep -q '^brew "age"' "$DOTFILES_DIR/$S/Brewfile"; grep -q '^brew "sops"' "$DOTFILES_DIR/$S/Brewfile"
  ! grep -qvE '^(#|$)' "$DOTFILES_DIR/$S/manifest.txt"
  DOTFILES_SECRETS_MANIFEST="$DOTFILES_DIR/$S/manifest.txt" run bash "$DOTFILES_DIR/$S/install.sh"
  [[ "$output" != *"missing secrets"* ]]
}

@test "install creates the dir, generates the age key once, writes age.pub, and is idempotent" {
  fake_age_keygen
  run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ "$(stat -c %a "$HOME/.secrets" 2>/dev/null || stat -f %Lp "$HOME/.secrets")" = "700" ]
  [ -f "$HOME/.secrets/age.key" ]; [ "$(stat -c %a "$HOME/.secrets/age.key" 2>/dev/null || stat -f %Lp "$HOME/.secrets/age.key")" = "600" ]
  [[ "$output" == *"back it up"* ]]
  [ "$(cat "$HOME/.secrets/age.pub")" = "age1fakepublickey" ]
  [[ "$output" == *"GITHUB_TOKEN"* ]]   # no secrets.yaml yet: every manifest key is missing
  run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [[ "$output" == *"skip"*"age.key"* ]]; [[ "$output" != *"back it up"* ]]
}

@test "dry run creates nothing" {
  fake_age_keygen
  DRY_RUN=1 run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ ! -e "$HOME/.secrets/age.key" ]; [ ! -e "$HOME/.secrets/age.pub" ]
}

@test "without age installed, install still creates the dir and says what to do" {
  PATH="$HOME/bin:/usr/bin:/bin" run bash "$DOTFILES_DIR/$S/install.sh"; [ "$status" -eq 0 ]
  [ -d "$HOME/.secrets" ]; [[ "$output" == *"age not installed"* ]]
}

@test "secrets_missing checks keys inside secrets.yaml through sops" {
  mkdir -p "$HOME/.secrets"; touch "$HOME/.secrets/secrets.yaml"
  fake_sops "GITHUB_TOKEN"
  [ -z "$(secrets_missing)" ]
  fake_sops "OTHER"
  [[ "$(secrets_missing)" == *"GITHUB_TOKEN"* ]]
}

@test "shell.zsh points sops at the key and the recipient, and parses" {
  zsh -n "$DOTFILES_DIR/$S/shell.zsh"
  mkdir -p "$HOME/.secrets"; echo age1fakepublickey > "$HOME/.secrets/age.pub"
  run zsh -c "source '$DOTFILES_DIR/$S/shell.zsh'; print -r -- \$SOPS_AGE_KEY_FILE \$SOPS_AGE_RECIPIENTS"
  [ "$output" = "$HOME/.secrets/age.key age1fakepublickey" ]
  rm "$HOME/.secrets/age.pub"
  run zsh -c "source '$DOTFILES_DIR/$S/shell.zsh'; print -r -- \${SOPS_AGE_RECIPIENTS:-unset}"
  [ "$output" = "unset" ]
}

@test "with-secrets passes only the named secrets, from any shell" {
  f="$DOTFILES_DIR/$S/home/.local/bin/with-secrets"
  [ -x "$f" ]
  cat > "$HOME/bin/sops" <<'FAKE'
#!/bin/sh
[ "$SOPS_AGE_KEY_FILE" = "$HOME/.secrets/age.key" ] || exit 9
case "$*" in
  *'["DEV_A"]'*) printf 'alpha' ;;
  *'["DEV_B"]'*) printf 'bravo' ;;
  *) exit 1 ;;
esac
FAKE
  chmod +x "$HOME/bin/sops"
  run env -i HOME="$HOME" PATH="$HOME/bin:/usr/bin:/bin" /bin/bash -c "'$f' DEV_A -- 'echo \"a=\${DEV_A:-} b=\${DEV_B:-}\"'"
  [ "$status" -eq 0 ]
  [ "$output" = "a=alpha b=" ]
}

@test "with-secrets fails on an unknown name and without a separator" {
  f="$DOTFILES_DIR/$S/home/.local/bin/with-secrets"
  printf '#!/bin/sh\nexit 1\n' > "$HOME/bin/sops"; chmod +x "$HOME/bin/sops"
  run "$f" NOPE -- true
  [ "$status" -ne 0 ]
  case "$output" in *NOPE*) ;; *) false ;; esac
  run "$f" 'echo hi'
  [ "$status" -ne 0 ]
  case "$output" in *usage*) ;; *) false ;; esac
  run env -i HOME="$HOME" PATH="$HOME/bin:/usr/bin:/bin" /bin/bash "$f" -- true
  [ "$status" -eq 2 ]
  case "$output" in *usage*) ;; *) false ;; esac
}

@test "zsh no longer defines a with-secrets function" {
  grep -q 'SOPS_AGE_KEY_FILE' "$DOTFILES_DIR/$S/shell.zsh"
  run grep -q 'with-secrets()' "$DOTFILES_DIR/$S/shell.zsh"
  [ "$status" -eq 1 ]
}
