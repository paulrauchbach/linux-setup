#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

update_config() {
	local extension_dirs=(
		"$HOME/.local/share/gnome-shell/extensions"
		"/usr/share/gnome-shell/extensions"
	)
	local known_uuids=(
		"ubuntu-appindicators@ubuntu.com"
		"appindicatorsupport@rgcjonas.gmail.com"
	)
	local known_uuid
	local extension_dir
	local extension_path
	local extension_uuid
	local extension_uuid_lower
	local enabled=0

	command -v gnome-extensions >/dev/null 2>&1 || return 0

	if gsettings list-schemas | grep -qxF org.gnome.shell.extensions.appindicator; then
		gsettings set org.gnome.shell.extensions.appindicator icon-size 16
		gsettings set org.gnome.shell.extensions.appindicator icon-spacing 8
		gsettings set org.gnome.shell.extensions.appindicator tray-order 1
		gsettings set org.gnome.shell.extensions.appindicator tray-pos right
		gsettings set org.gnome.shell.extensions.appindicator legacy-tray-enabled true
	fi

	for known_uuid in "${known_uuids[@]}"; do
		if gnome-extensions info "$known_uuid" >/dev/null 2>&1; then
			run_quiet "Enabling GNOME tray extension $known_uuid" \
				gnome-extensions enable "$known_uuid" || true
			enabled=1
		fi
	done

	for extension_dir in "${extension_dirs[@]}"; do
		[ -d "$extension_dir" ] || continue

		for extension_path in "$extension_dir"/*; do
			[ -d "$extension_path" ] || continue
			extension_uuid="$(basename "$extension_path")"
			extension_uuid_lower="${extension_uuid,,}"

			case "$extension_uuid_lower" in
				*indicator* | *kstatus*)
					if gnome-extensions info "$extension_uuid" 2>/dev/null |
						grep -qiE 'appindicator|kstatusnotifier|tray support|indicator'; then
						run_quiet "Enabling GNOME tray extension $extension_uuid" \
							gnome-extensions enable "$extension_uuid" || true
						enabled=1
					fi
					;;
			esac
		done
	done

	if [ "$enabled" -eq 0 ]; then
		log_warn "GNOME AppIndicator extension was not found; install gnome-shell-extension-appindicator and re-run 'linux-setup update gnome-tray'."
	fi
}
