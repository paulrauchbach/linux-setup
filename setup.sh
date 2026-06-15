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

DEV_PACKAGES=(
	pipx
)

# TODO(#1): The concrete desktop GUI application list is deliberately deferred.
# The desktop tier is fully wired as the top additive layer (essentials + dev +
# desktop); only this package set stays empty until the app list is decided.
# See https://github.com/paulrauchbach/linux-setup/issues/1.
DESKTOP_PACKAGES=()

usage() {
	cat <<'EOF'
Usage: setup.sh [essentials|dev|desktop] [options]

Options:
  --config              Apply personal shell, tmux, and git config
  --no-config           Install tools without touching dotfiles
  --name NAME           Git user.name (used with --config)
  --email EMAIL         Git user.email (used with --config)
  --with EXTRAS         Comma-separated: docker,ollama,claude,node-clis
                        Use --with none to explicitly select no extras
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
		essentials | dev | desktop)
			return 0
			;;
		*)
			die "Unknown tier '$1'. Choose essentials, dev, or desktop."
			;;
	esac
}

normalize_extras() {
	local normalized=""
	local extra
	local saw_none=0

	while IFS= read -r extra; do
		extra="${extra#"${extra%%[![:space:]]*}"}"
		extra="${extra%"${extra##*[![:space:]]}"}"
		[ -n "$extra" ] || continue

		case "$extra" in
			none)
				[ -z "$normalized" ] || die "'none' cannot be combined with other extras."
				saw_none=1
				continue
				;;
			docker | ollama | claude | node-clis)
				[ "$saw_none" -eq 0 ] || die "'none' cannot be combined with other extras."
				;;
			*)
				die "Unknown extra '$extra'. Choose docker, ollama, claude, or node-clis."
				;;
		esac

		case ",$normalized," in
			*",$extra,"*)
				continue
				;;
		esac

		if [ -n "$normalized" ]; then
			normalized="$normalized,$extra"
		else
			normalized="$extra"
		fi
	done < <(printf '%s\n' "$1" | tr ',' '\n')

	printf '%s\n' "$normalized"
}

has_extra() {
	local extras="$1"
	local expected="$2"

	case ",$extras," in
		*",$expected,"*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

format_extras() {
	local extras="$1"

	if [ -z "$extras" ]; then
		printf 'none\n'
	else
		printf '%s\n' "${extras//,/, }"
	fi
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
	local extras="$3"
	local full_name="$4"
	local email="$5"
	local summary
	local extras_display

	extras_display="$(format_extras "$extras")"

	summary="Tier: $tier
Extras: $extras_display
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
	local tier="$1"
	local extras="$2"
	local config_enabled="$3"
	local extras_display
	local recap

	extras_display="$(format_extras "$extras")"
	recap="Installed tier: $tier
Extras: $extras_display
Config applied: $config_enabled"

	if [ "$config_enabled" = "yes" ]; then
		recap="$recap
Shell: run 'exec zsh' now; new login sessions use zsh by default."
	fi

	if has_extra "$extras" docker; then
		recap="$recap
Docker: log out and back in for group membership to take effect."
	fi

	if [ "$config_enabled" = "no" ] &&
		{ has_extra "$extras" claude || has_extra "$extras" docker; }; then
		recap="$recap
PATH: ensure \$HOME/.local/bin is available in your shell."
	fi

	if [ "$config_enabled" = "no" ] &&
		{ [ "$tier" = "dev" ] || [ "$tier" = "desktop" ] || has_extra "$extras" node-clis; }; then
		recap="$recap
mise: activate mise in your shell to use managed runtimes and Node CLIs."
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
	local extras_arg_set=0
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
				extras_arg_set=1
				shift 2
				;;
			--with=*)
				extras_arg="${1#*=}"
				extras_arg_set=1
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
	local extras=""
	local extras_set=0

	if [ -n "$tier" ]; then
		validate_tier "$tier"
	fi

	if [ "$extras_arg_set" -eq 1 ]; then
		extras="$extras_arg"
		extras_set=1
	elif [ "${LINUX_SETUP_EXTRAS+x}" = "x" ]; then
		extras="$LINUX_SETUP_EXTRAS"
		extras_set=1
	fi

	if [ "$extras_set" -eq 1 ]; then
		extras="$(normalize_extras "$extras")"
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

	if [ "$extras_set" -eq 0 ] && has_interactive_tty; then
		local extras_selection
		extras_selection="$(ui_choose_extras)" || die "Extras selection cancelled."
		extras="$(normalize_extras "$extras_selection")"
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

	show_preflight "$tier" "$config_value" "$extras" "$full_name" "$email"

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
	install_fastfetch
	install_github_cli

	if [ "$tier" = "dev" ] || [ "$tier" = "desktop" ]; then
		log_title "Installing dev tools"
		install_mise_defaults
		apt_install "${DEV_PACKAGES[@]}"
		install_lazygit
	fi

	if [ "$tier" = "desktop" ]; then
		log_title "Installing desktop layer"
		install_desktop "${DESKTOP_PACKAGES[@]+"${DESKTOP_PACKAGES[@]}"}"
	fi

	if [ -n "$extras" ]; then
		log_title "Installing extras"
		install_extras "$extras"
	fi

	if [ "$config_value" = "yes" ]; then
		log_title "Applying personal config"
		apply_personal_config "$full_name" "$email"
	fi

	show_recap "$tier" "$extras" "$config_value"
}

main "$@"
