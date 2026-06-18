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

# Desktop GUI packages installed straight from the distro apt repository.
# Apps that need a third-party signed repo (VS Code, Signal, Spotify, Brave
# Origin), the Mozilla-repo Thunderbird, and the Nerd Font are handled by their
# own installers in install_desktop.
DESKTOP_PACKAGES=(
	alacritty
	keepassxc
	vlc
)

usage() {
	cat <<'EOF'
Usage: setup.sh [essentials|dev|desktop] [options]

Options:
  --config              Apply personal shell, tmux, and git config
  --no-config           Install tools without touching dotfiles
  --name NAME           Git user.name (used with --config)
  --email EMAIL         Git user.email (used with --config)
  --with EXTRAS         Comma-separated: docker,ollama,claude,agent-harnesses
                        Use --with none to explicitly select no extras
  -h, --help            Show this help

Environment:
  LINUX_SETUP_MODE
  LINUX_SETUP_TIER
  LINUX_SETUP_CONFIG
  LINUX_SETUP_FULL_NAME
  LINUX_SETUP_EMAIL
  LINUX_SETUP_EXTRAS
  LINUX_SETUP_UPDATE_CONFIGS
EOF
}

validate_mode() {
	case "$1" in
		install | update-config)
			return 0
			;;
		*)
			die "Unknown mode '$1'. Choose install or update-config."
			;;
	esac
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
			docker | ollama | claude | agent-harnesses)
				[ "$saw_none" -eq 0 ] || die "'none' cannot be combined with other extras."
				;;
			*)
				die "Unknown extra '$extra'. Choose docker, ollama, claude, or agent-harnesses."
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

normalize_configs() {
	local normalized=""
	local config

	while IFS= read -r config; do
		config="${config#"${config%%[![:space:]]*}"}"
		config="${config%"${config##*[![:space:]]}"}"
		[ -n "$config" ] || continue

		case "$config" in
			zsh | tmux | git | alacritty | vscode | brave)
				;;
			*)
				die "Unknown config '$config'. Choose zsh, tmux, git, alacritty, vscode, or brave."
				;;
		esac

		case ",$normalized," in
			*",$config,"*)
				continue
				;;
		esac

		if [ -n "$normalized" ]; then
			normalized="$normalized,$config"
		else
			normalized="$config"
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

has_config() {
	local configs="$1"
	local expected="$2"

	case ",$configs," in
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

format_configs() {
	local configs="$1"

	if [ -z "$configs" ]; then
		printf 'none\n'
	else
		printf '%s\n' "${configs//,/, }"
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

	if [ "$tier" = "desktop" ]; then
		recap="$recap
Brave Origin: complete the one-time free activation on first launch, then verify the managed policy at brave://policy.
Fonts: start a new session or run 'fc-cache -f' so apps pick up JetBrainsMono Nerd Font."
	fi

	if [ "$config_enabled" = "no" ] &&
		{ has_extra "$extras" claude || has_extra "$extras" docker || has_extra "$extras" agent-harnesses; }; then
		recap="$recap
PATH: ensure \$HOME/.local/bin is available in your shell."
	fi

	if [ "$config_enabled" = "no" ] &&
		{ [ "$tier" = "dev" ] || [ "$tier" = "desktop" ]; }; then
		recap="$recap
mise: activate mise in your shell to use managed runtimes and Node CLIs."
	fi

	if [ "${#INSTALL_FAILURES[@]}" -gt 0 ]; then
		recap="$recap

Skipped (review the log above): ${INSTALL_FAILURES[*]}"
	fi

	if has_interactive_tty && command -v gum >/dev/null 2>&1; then
		ui_box "Setup complete" "$recap"
	else
		log_title "Setup complete"
		printf '%s\n' "$recap"
	fi
}

show_update_config_preflight() {
	local configs="$1"
	local full_name="$2"
	local email="$3"
	local summary

	summary="Configs: $(format_configs "$configs")"

	if has_config "$configs" git; then
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

show_update_config_recap() {
	local configs="$1"
	local recap

	recap="Updated configs: $(format_configs "$configs")"

	if has_config "$configs" zsh; then
		recap="$recap
Shell: run 'exec zsh' now; new login sessions use zsh by default."
	fi

	if has_config "$configs" brave; then
		recap="$recap
Brave Origin: verify the managed policy at brave://policy."
	fi

	if has_interactive_tty && command -v gum >/dev/null 2>&1; then
		ui_box "Config update complete" "$recap"
	else
		log_title "Config update complete"
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
	local mode="${LINUX_SETUP_MODE:-}"
	local update_configs="${LINUX_SETUP_UPDATE_CONFIGS:-}"
	local extras=""
	local extras_set=0

	if [ -n "$mode" ]; then
		validate_mode "$mode"
	fi

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

	if [ -z "$mode" ]; then
		if has_interactive_tty; then
			mode="$(ui_choose_mode)" || die "Mode selection cancelled."
			validate_mode "$mode"
		else
			mode="install"
		fi
	fi

	if [ "$mode" = "update-config" ]; then
		if [ -z "$update_configs" ]; then
			has_interactive_tty ||
				die "Config selection is required for a non-interactive update. Set LINUX_SETUP_UPDATE_CONFIGS."
			update_configs="$(ui_choose_configs)" || die "Config selection cancelled."
		fi

		update_configs="$(normalize_configs "$update_configs")"
		[ -n "$update_configs" ] || die "No configs selected."

		if has_config "$update_configs" git; then
			if [ -z "$full_name" ]; then
				has_interactive_tty ||
					die "Git name is required when updating git config. Pass --name or set LINUX_SETUP_FULL_NAME."
				full_name="$(prompt_nonempty "Full name" "Your Name")"
			fi

			if [ -z "$email" ]; then
				has_interactive_tty ||
					die "Git email is required when updating git config. Pass --email or set LINUX_SETUP_EMAIL."
				email="$(prompt_nonempty "Email" "you@example.com")"
			fi
		fi

		show_update_config_preflight "$update_configs" "$full_name" "$email"

		if has_interactive_tty && ! ui_confirm_run; then
			log_warn "Config update cancelled."
			return 0
		fi

		detect_platform
		log_title "Applying selected config"
		apply_selected_config "$update_configs" "$full_name" "$email"
		show_update_config_recap "$update_configs"
		return 0
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
	try_install "Essential packages" apt_install "${ESSENTIAL_PACKAGES[@]}"
	try_install "Fastfetch" install_fastfetch
	try_install "GitHub CLI" install_github_cli

	if [ "$tier" = "dev" ] || [ "$tier" = "desktop" ]; then
		log_title "Installing dev tools"
		try_install "mise runtimes" install_mise_defaults
		try_install "Dev packages" apt_install "${DEV_PACKAGES[@]}"
		try_install "lazygit" install_lazygit
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
