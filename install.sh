#!/bin/bash

set -euo pipefail

: "${HOME:?HOME is not set. Please run as a regular user.}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	bold=$'\033[1m'
	red=$'\033[31m'
	green=$'\033[32m'
	blue=$'\033[34m'
	reset=$'\033[0m'
else
	bold=""
	red=""
	green=""
	blue=""
	reset=""
fi

log_title() {
	printf '\n%s%s%s\n' "$bold" "$*" "$reset"
}

log_step() {
	printf '\n%s==>%s %s\n' "$blue" "$reset" "$*"
}

log_error() {
	printf '  %sERROR%s %s\n' "$red" "$reset" "$*" >&2
}

die() {
	log_error "$*"
	exit 1
}

run_quiet() {
	local message="$1"
	shift

	local log_file
	log_file="$(mktemp)"

	printf '  %s... ' "$message"
	if "$@" > "$log_file" 2>&1; then
		printf '%sOK%s\n' "$green" "$reset"
		rm -f "$log_file"
		return 0
	fi

	printf '%sFAILED%s\n' "$red" "$reset"
	log_error "$message failed. Command output:"
	sed 's/^/    /' "$log_file" >&2
	rm -f "$log_file"
	return 1
}

if [ "$EUID" -eq 0 ]; then
	die "Please do not run this script as root. Run it as your user with sudo privileges."
fi

REPO_URL="${LINUX_SETUP_REPO_URL:-https://github.com/paulrauchbach/linux-setup.git}"
REPO_REF="${LINUX_SETUP_REPO_REF:-main}"
INSTALL_DIR="${LINUX_SETUP_INSTALL_DIR:-$HOME/.local/share/linux-setup}"

log_title "Linux Setup"

log_step "Preparing bootstrap packages"
sudo -v
run_quiet "Updating apt metadata" sudo apt-get -qq update
run_quiet "Installing bootstrap packages" sudo apt-get install -y -qq ca-certificates curl git

mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -d "$INSTALL_DIR/.git" ]; then
	log_step "Updating linux-setup"
	run_quiet "Setting origin" git -C "$INSTALL_DIR" remote set-url origin "$REPO_URL"
	run_quiet "Fetching $REPO_REF" git -C "$INSTALL_DIR" fetch --quiet --depth=1 origin "$REPO_REF"
	run_quiet "Checking out $REPO_REF" git -C "$INSTALL_DIR" checkout --quiet -f FETCH_HEAD
else
	if [ -e "$INSTALL_DIR" ]; then
		die "$INSTALL_DIR exists but is not a git checkout. Move it aside and retry."
	fi

	log_step "Cloning linux-setup"
	run_quiet "Cloning $REPO_REF to $INSTALL_DIR" git clone --quiet --depth=1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"
fi

export LINUX_SETUP_INSTALL_DIR="$INSTALL_DIR"

log_step "Starting setup"
bash "$LINUX_SETUP_INSTALL_DIR/setup.sh"
