#!/bin/bash
# Install or update this AeroSpace config at ~/.config/aerospace.
#
#   curl -fsSL https://raw.githubusercontent.com/ahmedash95/aerospace-config/main/install.sh | bash
#
# - Installs AeroSpace and JankyBorders with Homebrew if they're missing (skip with NO_BREW=1)
# - Clones the repo to ~/.config/aerospace, or pulls if it's already there
# - Anything it would replace is kept as *.bak-<timestamp>
set -euo pipefail

repo_url="https://github.com/ahmedash95/aerospace-config.git"
tarball="https://codeload.github.com/ahmedash95/aerospace-config/tar.gz/refs/heads/main"
dest="$HOME/.config/aerospace"
stamp=$(date +%Y%m%d-%H%M%S)

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

backup() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    mv "$1" "$1.bak-$stamp"
    say "Backed up $1 -> $1.bak-$stamp"
  fi
}

has_git() {
  # On a fresh Mac /usr/bin/git is a stub that pops up the Command Line Tools installer
  command -v git >/dev/null && xcode-select -p >/dev/null 2>&1
}

install_deps() {
  [ "${NO_BREW:-}" = 1 ] && return
  if ! command -v brew >/dev/null; then
    say "Homebrew not found; install AeroSpace yourself: https://nikitabobko.github.io/AeroSpace/guide#installation"
    return
  fi
  if [ ! -d /Applications/AeroSpace.app ] && ! command -v aerospace >/dev/null; then
    say "Installing AeroSpace"
    brew install --cask nikitabobko/tap/aerospace
  fi
  if ! command -v borders >/dev/null; then
    say "Installing JankyBorders (focused window border)"
    brew install FelixKratz/formulae/borders
  fi
}

install_config() {
  if [ -d "$dest/.git" ] && git -C "$dest" remote get-url origin 2>/dev/null | grep -q 'ahmedash95/aerospace-config'; then
    say "Updating existing config in $dest"
    git -C "$dest" pull --ff-only
  else
    backup "$dest"
    mkdir -p "$(dirname "$dest")"
    if has_git; then
      say "Cloning config into $dest"
      git clone --quiet "$repo_url" "$dest"
    else
      say "git isn't set up; downloading a snapshot into $dest (rerun this installer later to update)"
      mkdir -p "$dest"
      curl -fsSL "$tarball" | tar -xz --strip-components 1 -C "$dest"
    fi
  fi
  chmod +x "$dest"/scripts/*.sh
  # AeroSpace refuses to start when a config exists in both places
  backup "$HOME/.aerospace.toml"
}

start_aerospace() {
  if command -v aerospace >/dev/null && aerospace reload-config 2>/dev/null; then
    say "AeroSpace config reloaded"
  elif [ -d /Applications/AeroSpace.app ]; then
    say "Starting AeroSpace (grant it Accessibility access when macOS asks)"
    open -a AeroSpace
  else
    say "Install AeroSpace, then start it; the config will load from $dest"
  fi
}

main() {
  [ "$(uname)" = Darwin ] || { echo "AeroSpace only runs on macOS" >&2; exit 1; }
  install_deps
  install_config
  start_aerospace
  say "Done. Edit $dest/aerospace.toml, then run 'aerospace reload-config'"
}

# Everything runs from here, so a partially downloaded script (curl | bash) does nothing
main "$@"
