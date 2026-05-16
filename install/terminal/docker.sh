#!/bin/bash

set -euo pipefail

. /etc/os-release

docker_os="$ID"
docker_suite="${VERSION_CODENAME:-}"

if [ "$docker_os" != "debian" ] && [ "$docker_os" != "ubuntu" ]; then
  if [[ "${ID_LIKE:-}" == *ubuntu* && -n "${UBUNTU_CODENAME:-}" ]]; then
    docker_os="ubuntu"
    docker_suite="$UBUNTU_CODENAME"
  else
    log_warn "Skipping Docker: automatic repository setup supports Debian and Ubuntu only."
    return 0 2>/dev/null || exit 0
  fi
fi

if [ -z "$docker_suite" ]; then
  log_warn "Skipping Docker: could not determine OS codename."
  return 0 2>/dev/null || exit 0
fi

# Add the official Docker repo
if [ ! -f /etc/apt/sources.list.d/docker.sources ]; then
  # Add Docker's official GPG key:
  run_quiet "Updating apt metadata" sudo apt-get -qq update
  run_quiet "Installing Docker repo prerequisites" sudo apt-get install -y -qq ca-certificates curl
  run_quiet "Creating apt keyring directory" sudo install -m 0755 -d /etc/apt/keyrings
  run_quiet "Downloading Docker signing key" sudo curl -fsSL "https://download.docker.com/linux/$docker_os/gpg" -o /etc/apt/keyrings/docker.asc
  run_quiet "Setting Docker signing key permissions" sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/$docker_os
Suites: $docker_suite
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  run_quiet "Updating apt metadata for Docker" sudo apt-get -qq update
fi

# Install Docker engine and standard plugins
run_quiet "Installing Docker Engine" sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Give this user privileged Docker access
run_quiet "Adding $USER to docker group" sudo usermod -aG docker "$USER"
