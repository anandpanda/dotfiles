#!/usr/bin/env bash
# lazygit on macOS reads ~/Library/Application Support/lazygit by default; point that at ours too.
set -euo pipefail
for f in log os link; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
[ "$(os_name)" = macos ] || exit 0
link_file "$DOTFILES_DIR/modules/lazygit/config/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
