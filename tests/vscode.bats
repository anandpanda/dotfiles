load helper
setup() { setup_home; for f in log os link module vscode; do source "$DOTFILES_DIR/lib/$f.sh"; done; V="$DOTFILES_DIR/modules/vscode"; }
teardown() { teardown_home; }

@test "user dir per os" {
  if [ "$(os_name)" = macos ]; then [ "$(vscode_user_dir)" = "$HOME/Library/Application Support/Code/User" ]; else [ "$(vscode_user_dir)" = "$HOME/.config/Code/User" ]; fi
}

@test "extension ids ignore comments and case" {
  printf '# group\nPub.Name  # why\n\nother.ext\n' > "$HOME/e.txt"
  run vscode_ext_list "$HOME/e.txt"
  [ "$output" = $'pub.name\nother.ext' ]
}

@test "shipped extension list is well formed" {
  run vscode_ext_list "$V/extensions.txt"
  [ "$status" -eq 0 ]; [ "${#lines[@]}" -ge 30 ]
  for id in "${lines[@]}"; do [[ "$id" =~ ^[a-z0-9-]+\.[a-z0-9-]+$ ]]; done
  [[ "$output" == *catppuccin.catppuccin-vsc* ]] && [[ "$output" == *charliermarsh.ruff* ]] && [[ "$output" == *anthropic.claude-code* ]]
  [[ "$output" != *black-formatter* ]] && [[ "$output" != *cmake* ]]
}

@test "config files are valid jsonc" {
  for f in settings.json keybindings.json tasks.json snippets/cpp.json; do jsonc_valid "$V/files/$f"; done
  echo '{ bad' > "$HOME/bad.json"; ! jsonc_valid "$HOME/bad.json"
}

@test "settings pin theme, font, format on save and ruff" {
  grep -q '"workbench.colorTheme": "Catppuccin Mocha"' "$V/files/settings.json"
  grep -q 'JetBrainsMono Nerd Font' "$V/files/settings.json"
  grep -q '"editor.formatOnSave": true' "$V/files/settings.json"
  grep -q 'charliermarsh.ruff' "$V/files/settings.json"
  grep -q '"editor.linkedEditing": true' "$V/files/settings.json"
}

# ---- install.sh with a fake `code` ----
fake_code() {
  mkdir -p "$HOME/bin"
  cat > "$HOME/bin/code" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/code.log"
case "$1" in
  --list-extensions) cat "$HOME/installed.txt" 2>/dev/null ;;
  --install-extension) echo "$2" >> "$HOME/installed.txt" ;;
  --uninstall-extension) grep -vix "$2" "$HOME/installed.txt" > "$HOME/i.tmp" || true; mv "$HOME/i.tmp" "$HOME/installed.txt" ;;
esac
FAKE
  chmod +x "$HOME/bin/code"; export PATH="$HOME/bin:$PATH"
}

@test "install creates the user dir and links config" {
  fake_code
  bash "$V/install.sh" >/dev/null
  u="$(vscode_user_dir)"
  [ -L "$u/settings.json" ] && [ -L "$u/keybindings.json" ] && [ -L "$u/tasks.json" ] && [ -L "$u/snippets/cpp.json" ]
  [ ! -L "$u" ]
}

@test "install installs only missing extensions and is a no-op on rerun" {
  fake_code; printf 'Catppuccin.catppuccin-vsc\neamodio.gitlens\n' > "$HOME/installed.txt"
  run bash "$V/install.sh"
  [[ "$output" == *"installed charliermarsh.ruff"* ]]
  ! grep -qx "installed catppuccin.catppuccin-vsc" <<<"$output"
  grep -qx "installed catppuccin.catppuccin-vsc-icons" <<<"$output"
  n=$(grep -c "install-extension" "$HOME/code.log"); [ "$n" -ge 30 ]
  : > "$HOME/code.log"
  run bash "$V/install.sh"
  [[ "$output" == *"skip extensions"* ]]
  ! grep -q "install-extension" "$HOME/code.log"
}

@test "overlay extensions are installed too" {
  fake_code; mkdir -p "$HOME/.dotfiles-work/modules/vscode"; echo "coder.coder-remote" > "$HOME/.dotfiles-work/modules/vscode/extensions.txt"
  run bash "$V/install.sh"
  [[ "$output" == *"installed coder.coder-remote"* ]]
}

@test "dry run links and installs nothing" {
  fake_code
  DRY_RUN=1 run bash "$V/install.sh"
  [[ "$output" == *"[dry] link"* ]] && [[ "$output" == *"[dry] install extension"* ]]
  [ ! -e "$(vscode_user_dir)/settings.json" ]
  ! grep -q "install-extension" "$HOME/code.log"
}

@test "no code on PATH warns and exits 0" {
  DOTFILES_CODE= run bash "$V/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"code"*"not"* ]]
  [ -L "$(vscode_user_dir)/settings.json" ]
}

# ---- doctor.sh and prune ----
@test "vscode doctor: clean after install" {
  fake_code; bash "$V/install.sh" >/dev/null
  run bash "$V/doctor.sh"
  [ "$status" -eq 0 ]
}

@test "vscode doctor: missing link and missing extension are problems" {
  fake_code; bash "$V/install.sh" >/dev/null
  rm "$(vscode_user_dir)/settings.json"
  grep -v ruff "$HOME/installed.txt" > "$HOME/i.tmp"; mv "$HOME/i.tmp" "$HOME/installed.txt"
  run bash "$V/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing link"*"settings.json"* ]]
  [[ "$output" == *"missing extension charliermarsh.ruff"* ]]
}

@test "vscode doctor: extra extension is info, overlay extension is not extra" {
  fake_code; mkdir -p "$HOME/.dotfiles-work/modules/vscode"; echo "coder.coder-remote" > "$HOME/.dotfiles-work/modules/vscode/extensions.txt"
  bash "$V/install.sh" >/dev/null; echo "some.leftover" >> "$HOME/installed.txt"
  run bash "$V/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"extra extension some.leftover"* ]]
  [[ "$output" != *"extra extension coder.coder-remote"* ]]
}

@test "vscode doctor: no code on PATH skips extension checks" {
  fake_code; bash "$V/install.sh" >/dev/null
  DOTFILES_CODE= run bash "$V/doctor.sh"
  [ "$status" -eq 0 ]
}

@test "vscode-prune uninstalls extras only after y" {
  fake_code; bash "$V/install.sh" >/dev/null; echo "some.leftover" >> "$HOME/installed.txt"
  printf 'n\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run bash "$DOTFILES_DIR/scripts/vscode-prune.sh"
  [ "$status" -eq 0 ]; grep -q "some.leftover" "$HOME/installed.txt"
  printf 'y\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run bash "$DOTFILES_DIR/scripts/vscode-prune.sh"
  [ "$status" -eq 0 ]; ! grep -q "some.leftover" "$HOME/installed.txt"
  grep -q "charliermarsh.ruff" "$HOME/installed.txt"
}

@test "vscode-prune with nothing extra says so" {
  fake_code; bash "$V/install.sh" >/dev/null
  run bash "$DOTFILES_DIR/scripts/vscode-prune.sh"
  [ "$status" -eq 0 ]; [[ "$output" == *"nothing to prune"* ]]
}

@test "vscode_bin: override, PATH, app bundle, or nothing" {
  fake_code
  [ "$(vscode_bin)" = "$HOME/bin/code" ]
  [ "$(DOTFILES_CODE=/x/code vscode_bin)" = "/x/code" ]
  DOTFILES_CODE= run vscode_bin; [ "$status" -ne 0 ]; [ -z "$output" ]
}

# ---- review fixes ----
@test "jsonc_valid respects strings and rejects real errors" {
  printf '{ "a": "**/node_modules/**", // c\n "b": { "x": true } }\n' > "$HOME/ok.json"; jsonc_valid "$HOME/ok.json"
  printf '{ "a": "**/node_modules/**", "b": { "x": treu } }\n' > "$HOME/bad.json"; ! jsonc_valid "$HOME/bad.json"
  printf '{ "s": "has // not a comment", "t": "/* nor this */" }\n' > "$HOME/str.json"; jsonc_valid "$HOME/str.json"
  run jsonc_keys "$V/files/settings.json"
  [[ "$output" == *"search.exclude"* ]] && [[ "$output" == *"files.watcherExclude"* ]]
}

@test "bits/stdc++.h shim compiles with the task's flags" {
  command -v g++ >/dev/null || skip "no g++"
  [ -f "$V/files/include/bits/stdc++.h" ]
  printf '#include <bits/stdc++.h>\nint main(){ std::vector<int> v{1,2}; std::cout << v.size() << "\\n"; }\n' > "$HOME/t.cpp"
  g++ -std=c++17 -O2 -Wall -I "$V/files/include" "$HOME/t.cpp" -o "$HOME/t" && [ "$("$HOME/t")" = "2" ]
  grep -q -- '-I \\"${env:HOME}/.local/include\\"' "$V/files/tasks.json"
  grep -q -- '.local/include' "$V/files/settings.json"
}

@test "install links the include shim into ~/.local/include" {
  fake_code; bash "$V/install.sh" >/dev/null
  [ -L "$HOME/.local/include/bits/stdc++.h" ]
}

@test "bundled pack members are on the list, clang-format extension is not" {
  run vscode_ext_list "$V/extensions.txt"
  [[ "$output" == *ms-python.vscode-python-envs* ]] && [[ "$output" == *ms-vscode.remote-explorer* ]]
  [[ "$output" != *xaver.clang-format* ]]
  grep -q '"editor.defaultFormatter": "ms-vscode.cpptools"' "$V/files/settings.json"
  ! grep -q 'C_Cpp.formatting' "$V/files/settings.json"
}

@test "settings: no hard-coded shell path, terminal font 14 with ligatures, updates default" {
  ! grep -q 'terminal.integrated.profiles' "$V/files/settings.json"
  grep -q '"terminal.integrated.fontSize": 14' "$V/files/settings.json"
  grep -q '"terminal.integrated.fontLigatures' "$V/files/settings.json"
  grep -q '"update.mode": "default"' "$V/files/settings.json"
}

@test "ext list reads files separately (no trailing-newline merge)" {
  printf 'a.b' > "$HOME/x.txt"; printf 'c.d\n' > "$HOME/y.txt"
  run vscode_ext_list "$HOME/x.txt" "$HOME/y.txt"
  [ "$output" = $'a.b\nc.d' ]
}

@test "vscode-prune restores listed extensions that a pack uninstall took with it" {
  fake_code; bash "$V/install.sh" >/dev/null
  # Fake pack behaviour: uninstalling some.pack also drops ms-vscode.cpptools.
  cat > "$HOME/bin/code" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$HOME/code.log"
case "$1" in
  --list-extensions) cat "$HOME/installed.txt" 2>/dev/null ;;
  --install-extension) echo "$2" >> "$HOME/installed.txt" ;;
  --uninstall-extension)
    grep -vix "$2" "$HOME/installed.txt" > "$HOME/i.tmp" || true; mv "$HOME/i.tmp" "$HOME/installed.txt"
    [ "$2" = some.pack ] && { grep -vix ms-vscode.cpptools "$HOME/installed.txt" > "$HOME/i.tmp" || true; mv "$HOME/i.tmp" "$HOME/installed.txt"; } ;;
esac
FAKE
  echo "some.pack" >> "$HOME/installed.txt"
  printf 'y\n' > "$HOME/tty"
  DOTFILES_TTY="$HOME/tty" run bash "$DOTFILES_DIR/scripts/vscode-prune.sh"
  [ "$status" -eq 0 ]
  ! grep -qi "some.pack" "$HOME/installed.txt"
  grep -qi "ms-vscode.cpptools" "$HOME/installed.txt"
  [[ "$output" == *"restored ms-vscode.cpptools"* ]]
}
