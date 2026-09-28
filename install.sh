#!/bin/bash
# Link this repo's AeroSpace config into place.
# Existing files are backed up with a .bak-<timestamp> suffix first.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
stamp=$(date +%Y%m%d-%H%M%S)

link() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak-$stamp"
    echo "backed up $dest -> $dest.bak-$stamp"
  fi
  ln -sfn "$src" "$dest"
  echo "linked $dest -> $src"
}

chmod +x "$repo"/scripts/*.sh
link "$repo/aerospace.toml"                 ~/.aerospace.toml
link "$repo/scripts/cycle-layout.sh"        ~/.config/aerospace/cycle-layout.sh
link "$repo/scripts/hide-ghost-windows.sh"  ~/.config/aerospace/hide-ghost-windows.sh

if command -v aerospace >/dev/null && aerospace reload-config 2>/dev/null; then
  echo "AeroSpace config reloaded"
else
  echo "AeroSpace isn't running; start it and the config will load"
fi
