#!/usr/bin/env bash

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	bold=$'\033[1m'
	dim=$'\033[2m'
	red=$'\033[31m'
	green=$'\033[32m'
	yellow=$'\033[33m'
	blue=$'\033[34m'
	reset=$'\033[0m'
else
	bold=""
	dim=""
	red=""
	green=""
	yellow=""
	blue=""
	reset=""
fi

LINUX_SETUP_OS_ID="unknown"
APT_METADATA_UPDATED=0
SUDO_KEEPALIVE_PID=""

log_title() {
	printf '\n%s%s%s\n' "$bold" "$*" "$reset"
}

log_step() {
	printf '\n%s==>%s %s\n' "$blue" "$reset" "$*"
}

log_info() {
	printf '  %s-%s %s\n' "$dim" "$reset" "$*"
}

log_success() {
	printf '  %sOK%s %s\n' "$green" "$reset" "$*"
}

log_warn() {
	printf '  %sWARN%s %s\n' "$yellow" "$reset" "$*" >&2
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
	if "$@" >"$log_file" 2>&1; then
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

detect_platform() {
	local ID=""

	if [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		source /etc/os-release
	fi

	LINUX_SETUP_OS_ID="${ID:-unknown}"
}

is_supported_platform() {
	[ "$LINUX_SETUP_OS_ID" = "debian" ] || [ "$LINUX_SETUP_OS_ID" = "ubuntu" ]
}

has_interactive_tty() {
	[ -t 1 ] && [ -r /dev/tty ] && [ -w /dev/tty ]
}

cleanup_sudo_keepalive() {
	if [ -n "$SUDO_KEEPALIVE_PID" ]; then
		kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
	fi
}

require_sudo() {
	if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
		return 0
	fi

	command -v sudo >/dev/null 2>&1 || die "sudo is required for package installation."

	log_step "Checking sudo access"
	sudo -v

	(
		while true; do
			sudo -n true
			sleep 50
		done
	) 2>/dev/null &
	SUDO_KEEPALIVE_PID="$!"
	trap cleanup_sudo_keepalive EXIT
}

apt_update() {
	local force="${1:-no}"

	is_supported_platform || return 0
	require_sudo

	if [ "$APT_METADATA_UPDATED" -eq 0 ] || [ "$force" = "yes" ]; then
		run_quiet "Updating apt metadata" sudo apt-get -qq update
		APT_METADATA_UPDATED=1
	fi
}

apt_install() {
	local available=()
	local missing=()
	local package

	if ! is_supported_platform; then
		log_warn "Skipping apt packages on unsupported platform '$LINUX_SETUP_OS_ID': $*"
		return 0
	fi

	apt_update

	for package in "$@"; do
		if apt-cache show "$package" >/dev/null 2>&1; then
			available+=("$package")
		else
			missing+=("$package")
		fi
	done

	if [ "${#available[@]}" -gt 0 ]; then
		run_quiet "Installing packages: ${available[*]}" sudo apt-get install -y -qq "${available[@]}"
	fi

	if [ "${#missing[@]}" -gt 0 ]; then
		log_warn "Packages unavailable from configured apt sources: ${missing[*]}"
	fi
}

add_signed_apt_repo() {
	local display_name="$1"
	local key_url="$2"
	local key_path="$3"
	local source_line="$4"
	local source_path="$5"
	local key_tmp
	local source_tmp

	is_supported_platform || {
		log_warn "Skipping $display_name repository on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	require_sudo
	key_tmp="$(mktemp)"
	source_tmp="$(mktemp)"

	run_quiet "Downloading $display_name signing key" curl -fsSL "$key_url" -o "$key_tmp"
	run_quiet "Installing $display_name signing key" sudo install -D -m 0644 "$key_tmp" "$key_path"
	printf '%s\n' "$source_line" >"$source_tmp"
	run_quiet "Installing $display_name apt source" sudo install -D -m 0644 "$source_tmp" "$source_path"

	rm -f "$key_tmp" "$source_tmp"
	apt_update yes
}

run_remote_script() {
	local display_name="$1"
	local url="$2"
	local interpreter="${3:-bash}"
	local script_tmp

	script_tmp="$(mktemp)"
	run_quiet "Downloading $display_name installer" curl -fsSL "$url" -o "$script_tmp"
	run_quiet "Running $display_name installer" "$interpreter" "$script_tmp"
	rm -f "$script_tmp"
}

ui_choose_tier() {
	gum choose --header "Choose an install tier" essentials dev desktop </dev/tty
}

ui_confirm_config() {
	if gum confirm --default=false "Apply personal config?" </dev/tty; then
		printf 'yes\n'
	else
		printf 'no\n'
	fi
}

ui_input() {
	local label="$1"
	local placeholder="$2"

	gum input --header "$label" --placeholder "$placeholder" </dev/tty
}

ui_box() {
	local title="$1"
	local body="$2"

	gum style \
		--border rounded \
		--border-foreground 4 \
		--padding "1 2" \
		"$title

$body"
}

ui_confirm_run() {
	gum confirm --default=true "Continue with this setup?" </dev/tty
}
