#!/usr/bin/env bash

install_config_file() {
	local source_file="$1"
	local target_file="$2"
	local target_dir
	local temporary_file

	target_dir="$(dirname "$target_file")"
	mkdir -p "$target_dir"

	if [ -f "$target_file" ] && cmp -s "$source_file" "$target_file"; then
		log_success "$target_file is already up to date"
		return 0
	fi

	temporary_file="$(mktemp "$target_dir/.linux-setup.XXXXXX")"
	if ! cp -p -- "$source_file" "$temporary_file"; then
		rm -f -- "$temporary_file"
		die "Could not stage $target_file."
	fi

	if ! run_quiet "Installing $target_file" mv -f -- "$temporary_file" "$target_file"; then
		rm -f -- "$temporary_file"
		return 1
	fi
}

install_or_update_git_repo() {
	local display_name="$1"
	local repo_url="$2"
	local destination="$3"

	if [ -d "$destination/.git" ]; then
		run_quiet "Updating $display_name" git -C "$destination" pull --ff-only --quiet
	elif [ -e "$destination" ]; then
		log_warn "Skipping $display_name install: $destination exists and is not a git checkout."
	else
		run_quiet "Installing $display_name" git clone --quiet --depth=1 "$repo_url" "$destination"
	fi
}

apply_git_config() {
	local full_name="$1"
	local email="$2"

	run_quiet "Setting git user.name" git config --global user.name "$full_name"
	run_quiet "Setting git user.email" git config --global user.email "$email"
}

config_root() {
	printf '%s/configs\n' "$LINUX_SETUP_INSTALL_DIR"
}

list_config_components() {
	local component_dir

	for component_dir in "$(config_root)"/*; do
		[ -d "$component_dir" ] || continue
		[ "$(basename "$component_dir")" != "manual" ] || continue
		[ -f "$component_dir/update.sh" ] || continue
		basename "$component_dir"
	done
}

format_config_components() {
	local formatted=""
	local component

	while IFS= read -r component; do
		if [ -n "$formatted" ]; then
			formatted="$formatted, $component"
		else
			formatted="$component"
		fi
	done < <(list_config_components)

	printf '%s\n' "$formatted"
}

component_update_script() {
	local component="$1"
	local update_script

	case "$component" in
		"" | [!a-z0-9]* | *[!a-z0-9-]*) return 1 ;;
	esac

	update_script="$(config_root)/$component/update.sh"
	[ -f "$update_script" ] || return 1
	printf '%s\n' "$update_script"
}

normalize_configs() {
	local normalized=""
	local config
	local candidate
	local candidates=()

	while IFS= read -r config; do
		config="${config#"${config%%[![:space:]]*}"}"
		config="${config%"${config##*[![:space:]]}"}"
		[ -n "$config" ] || continue

		if [ "$config" = "all" ]; then
			mapfile -t candidates < <(list_config_components)
		elif component_update_script "$config" >/dev/null; then
			candidates=("$config")
		else
			die "Unknown config '$config'. Choose all or one of: $(format_config_components)."
		fi

		for candidate in "${candidates[@]}"; do
			case ",$normalized," in
				*",$candidate,"*) continue ;;
			esac

			if [ -n "$normalized" ]; then
				normalized="$normalized,$candidate"
			else
				normalized="$candidate"
			fi
		done
	done < <(printf '%s\n' "$1" | tr ',' '\n')

	printf '%s\n' "$normalized"
}

component_applies_during_install() {
	local component="$1"
	local update_script

	update_script="$(component_update_script "$component")" || return 1
	(
		LINUX_SETUP_COMPONENT_DIR="$(dirname "$update_script")"
		export LINUX_SETUP_COMPONENT_DIR
		LINUX_SETUP_APPLY_DURING_INSTALL=no
		# Component scripts are discovered dynamically by directory name.
		# shellcheck disable=SC1090
		source "$update_script"
		case "$LINUX_SETUP_APPLY_DURING_INSTALL" in
			yes) return 0 ;;
			no) return 1 ;;
			*) die "Config component '$component' has an invalid LINUX_SETUP_APPLY_DURING_INSTALL value." ;;
		esac
	)
}

apply_config_component() {
	local component="$1"
	local update_script

	update_script="$(component_update_script "$component")" ||
		die "Unknown config '$component'. Choose one of: $(format_config_components)."

	(
		LINUX_SETUP_COMPONENT_DIR="$(dirname "$update_script")"
		export LINUX_SETUP_COMPONENT_DIR
		# Component scripts are discovered dynamically by directory name.
		# shellcheck disable=SC1090
		source "$update_script"
		declare -F update_config >/dev/null ||
			die "Config component '$component' does not define update_config."
		update_config
	)
}

apply_selected_config() {
	local configs="$1"
	local selected=()
	local component

	IFS=',' read -r -a selected <<<"$configs"
	for component in "${selected[@]}"; do
		apply_config_component "$component"
	done
}

apply_personal_config() {
	local full_name="$1"
	local email="$2"
	local component

	apply_git_config "$full_name" "$email"
	while IFS= read -r component; do
		component_applies_during_install "$component" || continue
		apply_config_component "$component"
	done < <(list_config_components)
}
