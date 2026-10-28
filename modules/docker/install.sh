#!/usr/bin/env bash
# Linux: Docker engine from Docker's apt repo, user in the docker group. macOS: Desktop is a cask.
set -euo pipefail
for f in log os; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
[ "$(os_name)" = linux ] || exit 0
command -v apt-get >/dev/null 2>&1 || {
  log_warn "docker: no apt; install the engine for your distro: https://docs.docker.com/engine/install/"
  exit 0
}
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "skip docker (engine already reachable)"
  exit 0
fi
if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
  log_warn "docker: installing the engine needs sudo; on a managed workspace use the docker it provides"
  exit 0
fi
list="${DOTFILES_APT_LIST:-/etc/apt/sources.list.d/docker.list}"
if [ -f "$list" ]; then
  echo "skip docker apt repo"
else
  if [ "${DRY_RUN:-0}" = 1 ]; then
    echo "[dry] add Docker apt repo and install docker-ce"
    exit 0
  fi
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  # shellcheck disable=SC1091
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" |
    sudo tee "$list" >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  echo "installed docker engine"
fi
if id -nG "$(id -un)" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
  echo "skip docker group"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] add $(id -un) to the docker group"
else
  sudo usermod -aG docker "$(id -un)" && echo "added $(id -un) to the docker group (log out and in)"
fi
