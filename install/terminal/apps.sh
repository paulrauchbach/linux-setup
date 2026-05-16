#!/bin/bash

set -euo pipefail

packages=(
  apache2-utils
  bat
  btop
  curl
  fd-find
  fzf
  git
  pipx
  plocate
  ripgrep
  tmux
  unzip
  wget
  zoxide
)

run_quiet "Installing base CLI packages" sudo apt-get install -y -qq "${packages[@]}"

optional_packages=(
  eza
  fastfetch
  lazygit
)

for package in "${optional_packages[@]}"; do
  if apt-cache show "$package" >/dev/null 2>&1; then
    run_quiet "Installing optional package: $package" sudo apt-get install -y -qq "$package"
  else
    log_warn "Skipping $package: package not available from configured apt sources."
  fi
done
