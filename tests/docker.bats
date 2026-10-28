load helper
D="modules/docker"
setup() {
  setup_home
  for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done
  mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
}
teardown() { teardown_home; }

@test "brewfiles: desktop on macos, engine on linux, lazydocker everywhere" {
  grep -q 'cask "docker-desktop"' "$DOTFILES_DIR/$D/Brewfile.macos"
  grep -q 'brew "docker"' "$DOTFILES_DIR/$D/Brewfile.linux"; grep -q 'docker-compose' "$DOTFILES_DIR/$D/Brewfile.linux"
  grep -q 'brew "lazydocker"' "$DOTFILES_DIR/$D/Brewfile"
}

@test "lazydocker config links and shell alias parses (no sudo, no engine: hook warns only)" {
  PATH="/usr/bin:/bin" run bash -c "source '$DOTFILES_DIR/lib/log.sh'; source '$DOTFILES_DIR/lib/os.sh'; source '$DOTFILES_DIR/lib/link.sh'; source '$DOTFILES_DIR/lib/module.sh'; module_apply '$DOTFILES_DIR/$D'"
  [ "$status" -eq 0 ]
  module_apply "$DOTFILES_DIR/$D" >/dev/null
  [ -L "$HOME/.config/lazydocker/config.yml" ]
  zsh -n "$DOTFILES_DIR/$D/shell.zsh"; grep -q "alias ld=" "$DOTFILES_DIR/$D/shell.zsh"
}

@test "install on macos only links the lazydocker config" {
  [ "$(os_name)" = macos ] || skip "macos only"
  run bash "$DOTFILES_DIR/$D/install.sh"; [ "$status" -eq 0 ]; [[ "$output" != *apt* ]]; [[ "$output" == *lazydocker* ]]
}

@test "install on linux sets up docker's apt repo once and adds the user to the group" {
  [ "$(os_name)" = linux ] || skip "linux only"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$HOME/bin/docker"; chmod +x "$HOME/bin/docker"
  for c in sudo apt-get gpg curl usermod install tee; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$HOME/cmd.log"\n[ "%s" = sudo ] && exec "$@"\nexit 0\n' "$c" "$c" > "$HOME/bin/$c"; chmod +x "$HOME/bin/$c"; done
  printf '#!/usr/bin/env bash\necho amd64\n' > "$HOME/bin/dpkg"; chmod +x "$HOME/bin/dpkg"
  printf '#!/usr/bin/env bash\necho "sudo $*" >> "$HOME/cmd.log"; [ "$1" = -n ] && exit 0; exec "$@"\n' > "$HOME/bin/sudo"
  printf '#!/usr/bin/env bash\n[ "$1" = -s ] && exit 1; echo amd64\n' > "$HOME/bin/dpkg"; chmod +x "$HOME/bin/dpkg"
  export DOTFILES_APT_LIST="$HOME/docker.list"
  run bash "$DOTFILES_DIR/$D/install.sh"; [ "$status" -eq 0 ]
  grep -q "apt-get install" "$HOME/cmd.log"; grep -q "usermod" "$HOME/cmd.log"
  printf '#!/usr/bin/env bash\n[ "$1" = -s ] && exit 0; echo amd64\n' > "$HOME/bin/dpkg"; : > "$HOME/cmd.log"
  run bash "$DOTFILES_DIR/$D/install.sh"; [[ "$output" == *"skip docker engine"* ]]
}

@test "doctor warns, not fails, when the engine is unreachable" {
  printf '#!/usr/bin/env bash\nexit 1\n' > "$HOME/bin/docker"; chmod +x "$HOME/bin/docker"
  run bash "$DOTFILES_DIR/$D/doctor.sh"; [ "$status" -eq 0 ]; [[ "$output" == *"not reachable"* ]]
  printf '#!/usr/bin/env bash\nexit 0\n' > "$HOME/bin/docker"
  run bash "$DOTFILES_DIR/$D/doctor.sh"; [ "$status" -eq 0 ]; [[ "$output" != *"not reachable"* ]]
}

# ---- review fixes ----
@test "lazydocker config is linked where macOS lazydocker reads it" {
  [ "$(os_name)" = macos ] || skip "macos only"
  module_apply "$DOTFILES_DIR/$D" >/dev/null
  [ "$(readlink "$HOME/Library/Application Support/lazydocker/config.yml")" = "$DOTFILES_DIR/$D/home/.config/lazydocker/config.yml" ]
}

@test "linux install: idempotency keys off the installed package, picks debian vs ubuntu, uses the .asc key" {
  [ "$(os_name)" = linux ] || skip "linux only"
  grep -q 'dpkg -s docker-ce' "$DOTFILES_DIR/$D/install.sh"
  grep -q 'docker.asc' "$DOTFILES_DIR/$D/install.sh"; ! grep -q 'gpg --dearmor' "$DOTFILES_DIR/$D/install.sh"
  grep -q 'ID_LIKE' "$DOTFILES_DIR/$D/install.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$HOME/bin/docker"; chmod +x "$HOME/bin/docker"
  for c in apt-get curl usermod install tee; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$HOME/cmd.log"\nexit 0\n' "$c" > "$HOME/bin/$c"; chmod +x "$HOME/bin/$c"; done
  printf '#!/usr/bin/env bash\necho "sudo $*" >> "$HOME/cmd.log"; [ "$1" = -n ] && exit 0; exec "$@"\n' > "$HOME/bin/sudo"
  printf '#!/usr/bin/env bash\n[ "$1" = -s ] && exit 1; echo amd64\n' > "$HOME/bin/dpkg"; chmod +x "$HOME/bin/sudo" "$HOME/bin/dpkg"
  printf 'ID=debian\nVERSION_CODENAME=bookworm\n' > "$HOME/os-release"
  DOTFILES_OS_RELEASE="$HOME/os-release" DOTFILES_APT_LIST="$HOME/docker.list" run bash "$DOTFILES_DIR/$D/install.sh"
  [ "$status" -eq 0 ]; grep -q "linux/debian" "$HOME/cmd.log"
  printf '#!/usr/bin/env bash\n[ "$1" = -s ] && exit 0; echo amd64\n' > "$HOME/bin/dpkg"; : > "$HOME/cmd.log"
  DOTFILES_OS_RELEASE="$HOME/os-release" DOTFILES_APT_LIST="$HOME/docker.list" run bash "$DOTFILES_DIR/$D/install.sh"
  [[ "$output" == *"skip docker engine"* ]]; ! grep -q "apt-get install" "$HOME/cmd.log"
}
