set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Full install with a profile (personal | work). Extra args: --dry-run, --overlay URL
install profile="personal" *args="":
    ./install.sh {{profile}} {{args}}

# Pull latest and reinstall with the remembered profile
update:
    git -C "{{justfile_directory()}}" pull --ff-only
    brew update --quiet && brew upgrade --quiet
    command -v mise >/dev/null && mise up --quiet || true
    ./install.sh

# Read-only drift report
doctor:
    ./doctor.sh

# shellcheck + shfmt on every script
lint:
    shellcheck install.sh doctor.sh bootstrap.sh lib/*.sh scripts/*.sh modules/*/*.sh
    shfmt -i 2 -ci -d install.sh doctor.sh bootstrap.sh lib scripts $(find modules -name '*.sh')
    for f in $(find modules -name '*.zsh' -o -name '.zsh*' -type f); do zsh -n "$f"; done

# bats unit tests
unit:
    bats tests

# Smoke test the installer in a clean Ubuntu container
test:
    docker run --rm -v "{{justfile_directory()}}:/dotfiles:ro" ubuntu:24.04 bash -c \
      'apt-get update -qq && apt-get install -y -qq git curl sudo >/dev/null && useradd -m -s /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && cp -r /dotfiles /home/dev/.dotfiles && chown -R dev /home/dev && su dev -c "cd ~/.dotfiles && ./install.sh personal && z=/home/linuxbrew/.linuxbrew/bin/zsh && (grep -qxF \$z /etc/shells || echo \$z | sudo tee -a /etc/shells) && sudo chsh -s \$z dev && ./install.sh personal && ./doctor.sh"'

# Uninstall VS Code extensions that are on no list
vscode-prune:
    ./scripts/vscode-prune.sh

# Smoke test the server profile as a non-root user with NO sudo (a Coder-like workspace)
test-server:
    docker run --rm -v "{{justfile_directory()}}:/dotfiles:ro" ubuntu:24.04 bash -c \
      'apt-get update -qq && apt-get install -y -qq git curl build-essential procps file >/dev/null && useradd -m -s /bin/bash dev && mkdir -p /home/linuxbrew && chown dev /home/linuxbrew && cp -r /dotfiles /home/dev/.dotfiles && chown -R dev /home/dev && su dev -c "cd ~/.dotfiles && ./install.sh server && ./install.sh server && ./doctor.sh"'

# Scaffold a new module folder
module name:
    ./scripts/new-module.sh {{name}}

# Scaffold a new private overlay repo at path
overlay-init path:
    ./scripts/overlay-init.sh {{path}}
