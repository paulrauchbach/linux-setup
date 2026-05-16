#!/bin/bash

# Install mise for managing multiple versions of languages. See <https://mise.jdx.dev/getting-started.html>
run_quiet "Updating apt metadata" sudo apt-get -qq update
run_quiet "Installing mise repo prerequisites" sudo apt-get install -y -qq curl
run_quiet "Creating apt keyring directory" sudo install -dm 755 /etc/apt/keyrings

mise_keyring_tmp="$(mktemp)"
run_quiet "Downloading mise signing key" curl -fSsL https://mise.jdx.dev/gpg-key.pub -o "$mise_keyring_tmp"
run_quiet "Installing mise signing key" sudo install -m 644 "$mise_keyring_tmp" /etc/apt/keyrings/mise-archive-keyring.asc
rm -f "$mise_keyring_tmp"

echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list > /dev/null
run_quiet "Updating apt metadata for mise" sudo apt-get -qq update
run_quiet "Installing mise" sudo apt-get install -y -qq mise

# setup default version for python and node
run_quiet "Installing default Python with mise" mise use --global python@latest
run_quiet "Installing default Node.js with mise" mise use --global node@lts
