load helper
setup() {
  setup_home
  for f in log profile ssh; do source "$DOTFILES_DIR/lib/$f.sh"; done
}
teardown() { teardown_home; }

@test "key path per context" {
  [ "$(ssh_key_path work)" = "$HOME/.ssh/id_ed25519_work" ]
}

@test "contexts: personal only, work adds work" {
  run ssh_contexts_for_profile personal; [ "$output" = "personal" ]
  run ssh_contexts_for_profile work; [ "$output" = $'personal\nwork' ]
}

@test "existing key is reported present, no prompt" {
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/id_ed25519_personal"
  ssh_test() { return 0; }
  run ssh_ensure_key personal a@b
  [[ "$output" == *"present"* ]]
}

@test "missing key without tty warns and skips" {
  run ssh_ensure_key personal a@b
  [ "$status" -eq 0 ]
  [[ "$output" == *"no terminal"* ]]
  [ ! -f "$HOME/.ssh/id_ed25519_personal" ]
}

@test "dry run does not generate" {
  DRY_RUN=1 run ssh_ensure_key personal a@b
  [[ "$output" == *"[dry]"* ]]
}
