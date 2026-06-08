#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LINUX_SETUP_INSTALL_DIR="${LINUX_SETUP_INSTALL_DIR:-$SCRIPT_DIR}"

# shellcheck source=lib.sh
source "$LINUX_SETUP_INSTALL_DIR/lib.sh"
# shellcheck source=recipes.sh
source "$LINUX_SETUP_INSTALL_DIR/recipes.sh"
# shellcheck source=config.sh
source "$LINUX_SETUP_INSTALL_DIR/config.sh"

ESSENTIAL_PACKAGES=(
	bat
	btop
	curl
	eza
	fastfetch
	fd-find
	fzf
	git
	plocate
	ripgrep
	tmux
	unzip
	wget
	zoxide
)

usage() {
	cat <<'EOF'
Usage: setup.sh [essentials|dev|desktop] [options]

Options:
  --config              Apply personal shell, tmux, and git config
  --no-config           Install tools without touching dotfiles
  --name NAME           Git user.name (used with --config)
  --email EMAIL         Git user.email (used with --config)
  --with EXTRAS         Reserved for a later slice
  -h, --help            Show this help

Environment:
  LINUX_SETUP_TIER
  LINUX_SETUP_CONFIG
  LINUX_SETUP_FULL_NAME
  LINUX_SETUP_EMAIL
  LINUX_SETUP_EXTRAS
EOF
}

normalize_bool() {
	case "${1,,}" in
		1 | true | yes | y | on)
			printf 'yes\n'
			;;
		0 | false | no | n | off)
			printf 'no\n'
			;;
		*)
			die "Invalid config value '$1'. Use yes/no, true/false, or 1/0."
			;;
	esac
}

validate_tier() {
	case "$1" in
		essentials)
			return 0
			;;
		dev | desktop)
			die "Tier '$1' is not yet available. This slice supports essentials only."
			;;
		*)
			die "Unknown tier '$1'. Choose essentials, dev, or desktop."
			;;
	esac
}

prompt_nonempty() {
	local label="$1"
	local placeholder="$2"
	local value=""

	while [ -z "$value" ]; do
		value="$(ui_input "$label" "$placeholder")" || die "Could not read $label."
	done

	printf '%s\n' "$value"
}

show_preflight() {
	local tier="$1"
	local config_enabled="$2"
	local full_name="$3"
	local email="$4"
	local summary

	summary="Tier: $tier
Extras: none
Config: $config_enabled"

	if [ "$config_enabled" = "yes" ]; then
		summary="$summary
Git name: $full_name
Git email: $email"
	fi

	if has_interactive_tty; then
		ui_box "Linux Setup" "$summary"
	else
		log_title "Linux Setup"
		printf '%s\n' "$summary"
	fi
}

show_recap() {
	local config_enabled="$1"
	local recap="Installed: essentials
Extras: none
Config applied: $config_enabled"

	if [ "$config_enabled" = "yes" ]; then
		recap="$recap
Next step: restart your shell to load the zsh configuration."
	fi

	if has_interactive_tty && command -v gum >/dev/null 2>&1; then
		ui_box "Setup complete" "$recap"
	else
		log_title "Setup complete"
		printf '%s\n' "$recap"
	fi
}

main() {
	local tier_arg=""
	local config_arg=""
	local full_name_arg=""
	local email_arg=""
	local extras_arg=""
	local positional_seen=0

	while [ "$#" -gt 0 ]; do
		case "$1" in
			essentials | dev | desktop)
				if [ "$positional_seen" -eq 1 ]; then
					die "Only one tier may be selected."
				fi
				tier_arg="$1"
				positional_seen=1
				shift
				;;
			--config)
				config_arg="yes"
				shift
				;;
			--no-config)
				config_arg="no"
				shift
				;;
			--name)
				[ "$#" -ge 2 ] || die "--name requires a value."
				full_name_arg="$2"
				shift 2
				;;
			--name=*)
				full_name_arg="${1#*=}"
				shift
				;;
			--email)
				[ "$#" -ge 2 ] || die "--email requires a value."
				email_arg="$2"
				shift 2
				;;
			--email=*)
				email_arg="${1#*=}"
				shift
				;;
			--with)
				[ "$#" -ge 2 ] || die "--with requires a comma-separated value."
				extras_arg="$2"
				shift 2
				;;
			--with=*)
				extras_arg="${1#*=}"
				shift
				;;
			-h | --help)
				usage
				return 0
				;;
			--)
				shift
				[ "$#" -eq 0 ] || die "Unexpected argument '$1'."
				;;
			-*)
				die "Unknown option '$1'."
				;;
			*)
				die "Unknown tier '$1'. Choose essentials, dev, or desktop."
				;;
		esac
	done

	if [ "$EUID" -eq 0 ]; then
		die "Do not run this script as root. Run it as your user with sudo privileges."
	fi

	local tier="${tier_arg:-${LINUX_SETUP_TIER:-}}"
	local config_value="${config_arg:-${LINUX_SETUP_CONFIG:-}}"
	local full_name="${full_name_arg:-${LINUX_SETUP_FULL_NAME:-}}"
	local email="${email_arg:-${LINUX_SETUP_EMAIL:-}}"
	local extras="${extras_arg:-${LINUX_SETUP_EXTRAS:-}}"

	if [ -n "$tier" ]; then
		validate_tier "$tier"
	fi

	if [ -n "$extras" ]; then
		die "Extras are not yet available: $extras"
	fi

	if [ -n "$config_value" ]; then
		config_value="$(normalize_bool "$config_value")"
	fi

	detect_platform

	if has_interactive_tty; then
		install_gum
	fi

	if [ -z "$tier" ]; then
		has_interactive_tty ||
			die "Tier is required for a non-interactive run. Pass essentials or set LINUX_SETUP_TIER."
		tier="$(ui_choose_tier)" || die "Tier selection cancelled."
		validate_tier "$tier"
	fi

	if [ -z "$config_value" ]; then
		has_interactive_tty ||
			die "Config choice is required for a non-interactive run. Pass --config/--no-config or set LINUX_SETUP_CONFIG."
		config_value="$(ui_confirm_config)"
	fi

	if [ "$config_value" = "yes" ]; then
		if [ -z "$full_name" ]; then
			has_interactive_tty ||
				die "Git name is required when config is enabled. Pass --name or set LINUX_SETUP_FULL_NAME."
			full_name="$(prompt_nonempty "Full name" "Your Name")"
		fi

		if [ -z "$email" ]; then
			has_interactive_tty ||
				die "Git email is required when config is enabled. Pass --email or set LINUX_SETUP_EMAIL."
			email="$(prompt_nonempty "Email" "you@example.com")"
		fi
	fi

	show_preflight "$tier" "$config_value" "$full_name" "$email"

	if has_interactive_tty && ! ui_confirm_run; then
		log_warn "Setup cancelled."
		return 0
	fi

	if is_supported_platform; then
		require_sudo
	else
		log_warn "Unsupported platform '$LINUX_SETUP_OS_ID'. Debian/Ubuntu package steps will be skipped."
	fi

	log_title "Installing essentials"
	apt_install "${ESSENTIAL_PACKAGES[@]}"
	install_github_cli

	if [ "$config_value" = "yes" ]; then
		log_title "Applying personal config"
		apply_personal_config "$full_name" "$email"
	fi

	show_recap "$config_value"
}

main "$@"
