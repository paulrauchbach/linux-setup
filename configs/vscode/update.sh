#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	local source_settings="$LINUX_SETUP_COMPONENT_DIR/settings.json"
	local extensions_file="$LINUX_SETUP_COMPONENT_DIR/extensions.txt"
	local target_dir="$HOME/.config/Code/User"
	local extension

	command -v code >/dev/null 2>&1 || return 0

	if [ -f "$source_settings" ]; then
		install_config_file "$source_settings" "$target_dir/settings.json"
	fi

	if [ -f "$extensions_file" ]; then
		while IFS= read -r extension; do
			extension="${extension#"${extension%%[![:space:]]*}"}"
			extension="${extension%"${extension##*[![:space:]]}"}"
			[ -n "$extension" ] || continue
			case "$extension" in
				\#*) continue ;;
			esac
			run_quiet "Installing VS Code extension $extension" \
				code --install-extension "$extension" --force
		done <"$extensions_file"
	fi
}
