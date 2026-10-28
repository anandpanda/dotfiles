load helper
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  M="$HOME/mods"; mkdir -p "$M"
}
teardown() { teardown_home; }

@test "empty module is valid" {
  mkdir -p "$M/empty"; echo hi > "$M/empty/README.md"
  run module_apply "$M/empty"
  [ "$status" -eq 0 ]
}

@test "config dir links to ~/.config/<name>" {
  mkdir -p "$M/tool/config"; echo x > "$M/tool/config/tool.toml"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.config/tool")" = "$M/tool/config" ]
}

@test "home tree links files into HOME" {
  mkdir -p "$M/tool/home/.ssh"; echo x > "$M/tool/home/.ssh/config"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.ssh/config")" = "$M/tool/home/.ssh/config" ]
}

@test "install.sh runs with env" {
  mkdir -p "$M/tool"; printf '#!/usr/bin/env bash\necho "ran $HOME $DRY_RUN" > "$HOME/ran"\n' > "$M/tool/install.sh"
  chmod +x "$M/tool/install.sh"
  module_apply "$M/tool"
  [ "$(cat "$HOME/ran")" = "ran $HOME 0" ]
}

@test "failing install.sh fails apply" {
  mkdir -p "$M/tool"; printf '#!/usr/bin/env bash\nexit 3\n' > "$M/tool/install.sh"; chmod +x "$M/tool/install.sh"
  run module_apply "$M/tool"
  [ "$status" -ne 0 ]
}

@test "os restriction honoured" {
  mkdir -p "$M/mac"; printf 'os = "macos"\n' > "$M/mac/module.toml"
  mkdir -p "$M/lin"; printf 'os = "linux"\n' > "$M/lin/module.toml"
  mkdir -p "$M/any"
  run module_enabled_for_os "$M/any"; [ "$status" -eq 0 ]
  if [ "$(os_name)" = macos ]; then
    run module_enabled_for_os "$M/mac"; [ "$status" -eq 0 ]
    run module_enabled_for_os "$M/lin"; [ "$status" -ne 0 ]
  else
    run module_enabled_for_os "$M/lin"; [ "$status" -eq 0 ]
    run module_enabled_for_os "$M/mac"; [ "$status" -ne 0 ]
  fi
}

@test "module_brewfiles lists only existing" {
  mkdir -p "$M/a" "$M/b"; echo 'brew "jq"' > "$M/a/Brewfile"
  run module_brewfiles "$M/a" "$M/b"
  [ "$output" = "$M/a/Brewfile" ]
}

@test "module_checklists concatenates" {
  mkdir -p "$M/a" "$M/b"; echo one > "$M/a/CHECKLIST.md"; echo two > "$M/b/CHECKLIST.md"
  run module_checklists "$M/a" "$M/b"
  [ "$output" = $'one\ntwo' ]
}

@test "config link to a foreign dir is replaced, not populated" {
  mkdir -p "$M/tool/config" "$HOME/foreign"; echo x > "$M/tool/config/t"
  mkdir -p "$HOME/.config"; ln -s "$HOME/foreign" "$HOME/.config/tool"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.config/tool")" = "$M/tool/config" ]
  [ ! -e "$HOME/foreign/t" ]
}

@test "config link owned by another module of same name gets files laid inside" {
  mkdir -p "$M/tool/config" "$HOME/other/tool/config"; echo x > "$M/tool/config/t"
  mkdir -p "$HOME/.config"; ln -s "$HOME/other/tool/config" "$HOME/.config/tool"
  module_apply "$M/tool"
  [ "$(readlink "$HOME/.config/tool/t")" = "$M/tool/config/t" ]
}
