load helper
setup() { setup_home; source "$DOTFILES_DIR/lib/log.sh"; }
teardown() { teardown_home; }

@test "log_info prints message" {
  run log_info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "log_dry prefixes with [dry]" {
  run log_dry "would link"
  [[ "$output" == *"[dry]"*"would link"* ]]
}

@test "die exits 1 with message" {
  run die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}

@test "is_tty is false under bats" {
  run is_tty
  [ "$status" -ne 0 ]
}
