#!/bin/bash

keyring_tmp="$(mktemp)"

run_quiet "Creating GitHub CLI apt directories" sudo mkdir -p -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
run_quiet "Downloading GitHub CLI signing key" wget -q -O "$keyring_tmp" https://cli.github.com/packages/githubcli-archive-keyring.gpg
run_quiet "Installing GitHub CLI signing key" sudo install -m 644 "$keyring_tmp" /etc/apt/keyrings/githubcli-archive-keyring.gpg
rm -f "$keyring_tmp"

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

run_quiet "Updating apt metadata for GitHub CLI" sudo apt-get -qq update
run_quiet "Installing GitHub CLI" sudo apt-get install -y -qq gh
