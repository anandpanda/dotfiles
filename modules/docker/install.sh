#!/usr/bin/env bash
# macOS: Docker Desktop is a cask; point lazydocker's default dir at our config.
# Linux: Docker engine from Docker's apt repo (ubuntu or debian), user in the docker group.
set -euo pipefail
for f in log os link; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
if [ "$(os_name)" = macos ]; then
  link_file "$DOTFILES_DIR/modules/docker/home/.config/lazydocker/config.yml" "$HOME/Library/Application Support/lazydocker/config.yml"
  exit 0
fi
command -v apt-get >/dev/null 2>&1 || {
  log_warn "docker: no apt; install the engine for your distro: https://docs.docker.com/engine/install/"
  exit 0
}
if dpkg -s docker-ce >/dev/null 2>&1; then
  echo "skip docker engine"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "skip docker (engine already reachable)"
elif ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
  log_warn "docker: installing the engine needs sudo; on a managed workspace use the docker it provides"
  exit 0
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] add Docker apt repo and install docker-ce"
  exit 0
else
  osr="${DOTFILES_OS_RELEASE:-/etc/os-release}"
  # Docker publishes separate repos for ubuntu and debian; derivatives follow ID_LIKE.
  distro="$(
    # shellcheck disable=SC1090
    . "$osr"
    if [ "${ID:-}" = ubuntu ] || [ -n "${UBUNTU_CODENAME:-}" ]; then echo ubuntu; else echo debian; fi
  )"
  codename="$(
    # shellcheck disable=SC1090
    . "$osr"
    echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  )"
  [ -n "$codename" ] || die "docker: cannot determine the release codename from $osr"
  list="${DOTFILES_APT_LIST:-/etc/apt/sources.list.d/docker.list}"
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo curl -fsSL "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro $codename stable" |
    sudo tee "$list" >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  echo "installed docker engine"
fi
if id -nG "$(id -un)" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
  echo "skip docker group"
elif ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
  :
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] add $(id -un) to the docker group"
else
  sudo usermod -aG docker "$(id -un)" && echo "added $(id -un) to the docker group (log out and in)"
fi
