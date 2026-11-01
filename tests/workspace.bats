load helper
setup() { setup_home; }
teardown() { teardown_home; }

@test "work creates the personal and the work folders" {
  DOTFILES_PROFILE=work run bash "$DOTFILES_DIR/modules/workspace/install.sh"
  [ "$status" -eq 0 ]; [ -d "$HOME/personal" ]; [ -d "$HOME/work" ]
}

@test "server-work creates only the work folders: it declares no personal identity" {
  DOTFILES_PROFILE=server-work run bash "$DOTFILES_DIR/modules/workspace/install.sh"
  [ "$status" -eq 0 ]; [ -d "$HOME/work" ]; [ ! -e "$HOME/personal" ]
}

@test "personal creates only the personal folders" {
  DOTFILES_PROFILE=personal run bash "$DOTFILES_DIR/modules/workspace/install.sh"
  [ "$status" -eq 0 ]; [ -d "$HOME/personal" ]; [ ! -e "$HOME/work" ]
}
