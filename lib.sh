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
LINUX_SETUP_OS_CODENAME=""
APT_METADATA_UPDATED=0
SUDO_KEEPALIVE_PID=""
INSTALL_FAILURES=()

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

# Run a single installation step in isolation. A failure is logged and recorded
# in INSTALL_FAILURES, but try_install still returns success so that 'set -e'
# does not abort the rest of the setup. Wrapping the step in the 'if' condition
# also disables 'set -e' inside the installer, so a non-zero command part-way
# through is contained instead of killing the whole run.
try_install() {
	local label="$1"
	shift

	if "$@"; then
		return 0
	fi

	log_warn "$label did not complete; skipping it and continuing the setup."
	INSTALL_FAILURES+=("$label")
	return 0
}

detect_platform() {
	local ID=""
	local VERSION_CODENAME=""
	local UBUNTU_CODENAME=""

	if [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		source /etc/os-release
	fi

	LINUX_SETUP_OS_ID="${ID:-unknown}"
	LINUX_SETUP_OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
	export LINUX_SETUP_OS_ID LINUX_SETUP_OS_CODENAME
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

	if [ "$APT_METADATA_UPDATED" -eq 1 ] && [ "$force" != "yes" ]; then
		return 0
	fi

	if ! run_quiet "Updating apt metadata" sudo apt-get -qq update; then
		return 1
	fi

	APT_METADATA_UPDATED=1
	return 0
}

apt_install() {
	local available=()
	local missing=()
	local package

	if ! is_supported_platform; then
		log_warn "Skipping apt packages on unsupported platform '$LINUX_SETUP_OS_ID': $*"
		return 0
	fi

	apt_update || return 1

	for package in "$@"; do
		if apt-cache show "$package" >/dev/null 2>&1; then
			available+=("$package")
		else
			missing+=("$package")
		fi
	done

	if [ "${#available[@]}" -gt 0 ]; then
		run_quiet "Installing packages: ${available[*]}" sudo apt-get install -y -qq "${available[@]}" || return 1
	fi

	if [ "${#missing[@]}" -gt 0 ]; then
		log_warn "Packages unavailable from configured apt sources: ${missing[*]}"
	fi

	return 0
}

backup_system_file_for_linux_setup() {
	local file="$1"
	local backup

	[ -e "$file" ] || return 0

	backup="${file}.linux-setup-backup.$(date +%Y%m%d%H%M%S)"
	run_quiet "Backing up $file" sudo cp -a "$file" "$backup"
}

add_signed_apt_repo() {
	local display_name="$1"
	local key_url="$2"
	local key_path="$3"
	local source_line="$4"
	local source_path="$5"
	local key_tmp
	local source_tmp
	local status=0

	is_supported_platform || {
		log_warn "Skipping $display_name repository on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	require_sudo
	key_tmp="$(mktemp)"
	source_tmp="$(mktemp)"

	if run_quiet "Downloading $display_name signing key" curl -fsSL "$key_url" -o "$key_tmp" &&
		backup_system_file_for_linux_setup "$key_path" &&
		run_quiet "Installing $display_name signing key" sudo install -D -m 0644 "$key_tmp" "$key_path"; then
		printf '%s\n' "$source_line" >"$source_tmp"
		backup_system_file_for_linux_setup "$source_path" &&
			run_quiet "Installing $display_name apt source" sudo install -D -m 0644 "$source_tmp" "$source_path" || status=1
	else
		status=1
	fi

	rm -f "$key_tmp" "$source_tmp"

	if [ "$status" -ne 0 ]; then
		log_warn "$display_name repository could not be configured; cleaning up partial files."
		sudo rm -f "$key_path" "$source_path" 2>/dev/null || true
		return 1
	fi

	# Validate the new repository on its own. If its signing key cannot verify
	# the release (a rotated or expired key), 'apt-get update' would fail for
	# every later package too, so roll the repository back and refresh apt with
	# a clean source list before continuing.
	if ! apt_update yes; then
		log_warn "$display_name repository failed to validate; removing it so other installs are unaffected."
		sudo rm -f "$key_path" "$source_path" 2>/dev/null || true
		apt_update yes || true
		return 1
	fi

	return 0
}

run_remote_script() {
	local display_name="$1"
	local url="$2"
	local interpreter="${3:-bash}"
	local script_tmp
	local status=0

	script_tmp="$(mktemp)"
	if run_quiet "Downloading $display_name installer" curl -fsSL "$url" -o "$script_tmp"; then
		run_quiet "Running $display_name installer" "$interpreter" "$script_tmp" || status=1
	else
		status=1
	fi
	rm -f "$script_tmp"
	return "$status"
}

ui_choose_tier() {
	gum choose --header "Choose an install tier" essentials dev desktop </dev/tty
}

ui_choose_extras() {
	gum choose \
		--no-limit \
		--header "Choose optional extras (space to select)" \
		docker ollama claude agent-harnesses </dev/tty
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
