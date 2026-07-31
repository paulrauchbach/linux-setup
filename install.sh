#!/usr/bin/env bash

set -euo pipefail

: "${HOME:?HOME is not set. Please run as a regular user.}"

bootstrap_die() {
	printf 'linux-setup: %s\n' "$*" >&2
	exit 1
}

if [ "$EUID" -eq 0 ]; then
	bootstrap_die "Do not run this script as root. Run it as your user with sudo privileges."
fi

REPO_URL="${LINUX_SETUP_REPO_URL:-https://github.com/paulrauchbach/linux-setup.git}"
REPO_REF="${LINUX_SETUP_REPO_REF:-main}"
INSTALL_DIR="${LINUX_SETUP_INSTALL_DIR:-$HOME/.local/share/linux-setup}"

printf '\nLinux Setup\n\n'

missing_bootstrap_packages=()
for command_name in curl git; do
	command -v "$command_name" >/dev/null 2>&1 || missing_bootstrap_packages+=("$command_name")
done

if [ "${#missing_bootstrap_packages[@]}" -gt 0 ]; then
	command -v apt-get >/dev/null 2>&1 ||
		bootstrap_die "${missing_bootstrap_packages[*]} is required; automatic bootstrap supports apt-based systems only."
	command -v sudo >/dev/null 2>&1 || bootstrap_die "sudo is required to install bootstrap packages."
	printf '==> Preparing bootstrap packages\n'
	sudo -v
	sudo apt-get -qq update
	sudo apt-get install -y -qq ca-certificates "${missing_bootstrap_packages[@]}"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -d "$INSTALL_DIR/.git" ]; then
	git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL"
	local_commit="$(git -C "$INSTALL_DIR" rev-parse HEAD)"
	printf '\n==> Checking for linux-setup updates\n'
	git -C "$INSTALL_DIR" fetch --quiet --depth=1 origin "$REPO_REF"
	remote_commit="$(git -C "$INSTALL_DIR" rev-parse FETCH_HEAD^{commit})"
	if [ "$local_commit" != "$remote_commit" ]; then
		printf '==> Updating linux-setup\n'
		git -C "$INSTALL_DIR" checkout --quiet --detach -f FETCH_HEAD
	fi
else
	if [ -e "$INSTALL_DIR" ]; then
		bootstrap_die "$INSTALL_DIR exists but is not a git checkout. Move it aside and retry."
	fi

	printf '\n==> Cloning linux-setup\n'
	git clone --quiet --depth=1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"
fi

mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/linux-setup" ] ||
	! cmp -s "$INSTALL_DIR/linux-setup" "$HOME/.local/bin/linux-setup"; then
	install -m 0755 "$INSTALL_DIR/linux-setup" "$HOME/.local/bin/linux-setup"
fi

printf '\n==> Starting setup\n'
exec env LINUX_SETUP_INSTALL_DIR="$INSTALL_DIR" bash "$INSTALL_DIR/setup.sh" "$@"
