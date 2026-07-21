#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

gnome_schema_exists() {
	local schema="$1"
	gsettings list-schemas | grep -qxF "$schema"
}

gnome_set_if_schema() {
	local schema="$1"
	local key="$2"
	local value="$3"

	gnome_schema_exists "$schema" || return 0
	gsettings set "$schema" "$key" "$value"
}

gnome_extension_if_installed() {
	local action="$1"
	local uuid="$2"

	gnome-extensions info "$uuid" >/dev/null 2>&1 || return 1
	gnome-extensions "$action" "$uuid" >/dev/null 2>&1 || true
}

apply_gnome_extensions() {
	local extensions=(
		"tactile@lundal.io"
		"just-perfection-desktop@just-perfection"
		"blur-my-shell@aunetx"
		"space-bar@luchrioh"
		"undecorate@sun.wxg@gmail.com"
		"tophat@fflewddur.github.io"
		"AlphabeticalAppGrid@stuarthayhurst"
	)
	local missing=()
	local uuid

	gnome_extension_if_installed disable "tiling-assistant@ubuntu.com" || true
	gnome_extension_if_installed disable "ubuntu-dock@ubuntu.com" || true
	gnome_extension_if_installed disable "ding@rastersoft.com" || true
	gnome_extension_if_installed enable "ubuntu-appindicators@ubuntu.com" ||
		gnome_extension_if_installed enable "appindicatorsupport@rgcjonas.gmail.com" || true

	for uuid in "${extensions[@]}"; do
		if ! gnome_extension_if_installed enable "$uuid"; then
			missing+=("$uuid")
		fi
	done

	if [ "${#missing[@]}" -gt 0 ]; then
		log_warn "Optional GNOME extensions are not installed: ${missing[*]}. Install them with Extension Manager, then run 'linux-setup update gnome'."
	fi

	gnome_set_if_schema org.gnome.shell.extensions.tactile col-0 1
	gnome_set_if_schema org.gnome.shell.extensions.tactile col-1 2
	gnome_set_if_schema org.gnome.shell.extensions.tactile col-2 1
	gnome_set_if_schema org.gnome.shell.extensions.tactile col-3 0
	gnome_set_if_schema org.gnome.shell.extensions.tactile row-0 1
	gnome_set_if_schema org.gnome.shell.extensions.tactile row-1 1
	gnome_set_if_schema org.gnome.shell.extensions.tactile gap-size 32

	gnome_set_if_schema org.gnome.shell.extensions.just-perfection animation 2
	gnome_set_if_schema org.gnome.shell.extensions.just-perfection dash-app-running true
	gnome_set_if_schema org.gnome.shell.extensions.just-perfection workspace true
	gnome_set_if_schema org.gnome.shell.extensions.just-perfection workspace-popup false

	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.appfolder blur false
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.lockscreen blur false
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.screenshot blur false
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.window-list blur false
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.panel blur false
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.overview blur true
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.overview pipeline pipeline_default
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur true
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.dash-to-dock brightness 0.6
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.dash-to-dock sigma 30
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.dash-to-dock static-blur true
	gnome_set_if_schema org.gnome.shell.extensions.blur-my-shell.dash-to-dock style-dash-to-dock 0

	gnome_set_if_schema org.gnome.shell.extensions.space-bar.behavior smart-workspace-names false
	gnome_set_if_schema org.gnome.shell.extensions.space-bar.shortcuts enable-activate-workspace-shortcuts false
	gnome_set_if_schema org.gnome.shell.extensions.space-bar.shortcuts enable-move-to-workspace-shortcuts true
	gnome_set_if_schema org.gnome.shell.extensions.space-bar.shortcuts open-menu '@as []'

	gnome_set_if_schema org.gnome.shell.extensions.tophat show-icons false
	gnome_set_if_schema org.gnome.shell.extensions.tophat show-cpu false
	gnome_set_if_schema org.gnome.shell.extensions.tophat show-disk false
	gnome_set_if_schema org.gnome.shell.extensions.tophat show-mem false
	gnome_set_if_schema org.gnome.shell.extensions.tophat show-fs false
	gnome_set_if_schema org.gnome.shell.extensions.tophat network-usage-unit bits
	gnome_set_if_schema org.gnome.shell.extensions.tophat meter-fg-color "'#924d8b'"
	gnome_set_if_schema org.gnome.shell.extensions.alphabetical-app-grid folder-order-position end
	gnome_set_if_schema org.gnome.shell.extensions.dash-to-dock hot-keys false
}

apply_gnome_theme() {
	local background_dir="$HOME/.local/share/backgrounds"
	local background="$background_dir/tokyo-night.jpg"
	local background_url="${GNOME_BACKGROUND_URL:-https://raw.githubusercontent.com/basecamp/omakub/c873902/themes/tokyo-night/background.jpg}"
	local expected_sha256="${GNOME_BACKGROUND_SHA256:-c04a61df9928f1c1b078050078648bd9d717326e5cc19fc9de6228989af01f24}"
	local actual_sha256=""
	local temporary
	local background_uri

	if [ -f "$background" ]; then
		actual_sha256="$(sha256sum "$background" | cut -d' ' -f1)"
	fi
	if [ "$actual_sha256" != "$expected_sha256" ]; then
		mkdir -p "$background_dir"
		temporary="$(mktemp "$background_dir/.tokyo-night.XXXXXX")"
		if ! run_quiet "Downloading Tokyo Night wallpaper" curl -fsSL "$background_url" -o "$temporary"; then
			rm -f "$temporary"
			return 1
		fi
		actual_sha256="$(sha256sum "$temporary" | cut -d' ' -f1)"
		if [ "$actual_sha256" != "$expected_sha256" ]; then
			rm -f "$temporary"
			die "Tokyo Night wallpaper checksum mismatch."
		fi
		run_quiet "Installing Tokyo Night wallpaper" mv "$temporary" "$background"
	fi

	background_uri="file://$(realpath "$background")"
	gsettings set org.gnome.desktop.interface color-scheme prefer-dark
	gsettings set org.gnome.desktop.interface cursor-theme Yaru
	gsettings set org.gnome.desktop.interface gtk-theme Yaru-purple-dark
	gsettings set org.gnome.desktop.interface icon-theme Yaru-purple
	if gsettings list-keys org.gnome.desktop.interface | grep -qx accent-color; then
		gsettings set org.gnome.desktop.interface accent-color purple
	fi
	gsettings set org.gnome.desktop.background picture-uri "$background_uri"
	gsettings set org.gnome.desktop.background picture-uri-dark "$background_uri"
	gsettings set org.gnome.desktop.background picture-options zoom
}

apply_gnome_keybindings() {
	local binding_root="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
	local brave_command
	local number

	gsettings set org.gnome.mutter dynamic-workspaces false
	gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
	gsettings set org.gnome.desktop.wm.keybindings close "['<Super>w']"
	gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
	gsettings set org.gnome.desktop.wm.keybindings begin-resize "['<Super>BackSpace']"
	gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Shift>F11']"
	gsettings set org.gnome.settings-daemon.plugins.media-keys next "['<Shift>AudioPlay']"
	gsettings set org.gnome.desktop.wm.keybindings switch-input-source '@as []'

	for number in {1..9}; do
		gsettings set org.gnome.shell.keybindings "switch-to-application-$number" "['<Alt>$number']"
	done
	for number in {1..6}; do
		gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$number" "['<Super>$number']"
	done

	gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
		"['$binding_root/custom0/', '$binding_root/custom1/', '$binding_root/custom2/', '$binding_root/custom3/']"
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" name Ulauncher
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" command 'sh -c "pgrep -x ulauncher && { ulauncher-toggle || true; } || setsid -f ulauncher"'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" binding '<Super>space'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" name Flameshot
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" command 'sh -c -- "flameshot gui"'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" binding '<Control>Print'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" name 'New Alacritty Window'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" command alacritty
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" binding '<Shift><Alt>2'
	brave_command="$(command -v brave-origin 2>/dev/null || command -v brave-browser 2>/dev/null || true)"
	[ -n "$brave_command" ] || brave_command=brave-origin
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" name 'New Brave Window'
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" command "$brave_command --new-window"
	gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" binding '<Shift><Alt>1'
}

desktop_file_exists() {
	local id="$1"
	local directory
	for directory in \
		"$HOME/.local/share/applications" \
		"$HOME/.local/share/flatpak/exports/share/applications" \
		/usr/local/share/applications \
		/usr/share/applications \
		/var/lib/flatpak/exports/share/applications; do
		[ -f "$directory/$id" ] && return 0
	done
	return 1
}

first_desktop_file() {
	local id
	for id in "$@"; do
		if desktop_file_exists "$id"; then
			printf '%s\n' "$id"
			return 0
		fi
	done
	return 1
}

variant_list() {
	local result=""
	local id
	for id in "$@"; do
		[ -n "$id" ] && result+="'$id', "
	done
	printf '[%s]\n' "${result%, }"
}

apply_gnome_app_layout() {
	local favourites=()
	local favourite_values
	local id
	local alacritty_id
	local vscode_id
	local thunderbird_id
	local signal_id
	local spotify_id
	local vlc_id
	local candidates

	for candidates in \
		"brave-origin.desktop com.brave.Origin.desktop brave-browser.desktop" \
		"Alacritty.desktop org.alacritty.Alacritty.desktop" \
		"code.desktop" \
		"thunderbird.desktop org.mozilla.Thunderbird.desktop" \
		"signal-desktop.desktop org.signal.Signal.desktop" \
		"spotify.desktop com.spotify.Client.desktop" \
		"org.keepassxc.KeePassXC.desktop keepassxc.desktop" \
		"org.gnome.Nautilus.desktop nautilus.desktop" \
		"org.gnome.Settings.desktop gnome-control-center.desktop"; do
		# Candidate identifiers never contain whitespace.
		# shellcheck disable=SC2086
		id="$(first_desktop_file $candidates || true)"
		[ -n "$id" ] && favourites+=("$id")
	done
	if [ "${#favourites[@]}" -gt 0 ]; then
		printf -v favourite_values "'%s', " "${favourites[@]}"
		gsettings set org.gnome.shell favorite-apps "[${favourite_values%, }]"
	fi

	alacritty_id="$(first_desktop_file Alacritty.desktop org.alacritty.Alacritty.desktop || true)"
	vscode_id="$(first_desktop_file code.desktop || true)"
	thunderbird_id="$(first_desktop_file thunderbird.desktop org.mozilla.Thunderbird.desktop || true)"
	signal_id="$(first_desktop_file signal-desktop.desktop org.signal.Signal.desktop || true)"
	spotify_id="$(first_desktop_file spotify.desktop com.spotify.Client.desktop || true)"
	vlc_id="$(first_desktop_file vlc.desktop org.videolan.VLC.desktop || true)"

	gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'Sundry', 'YaST', 'Development', 'Communication', 'Media']"
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ name Development
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ apps "$(variant_list "$alacritty_id" "$vscode_id")"
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Communication/ name Communication
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Communication/ apps "$(variant_list "$thunderbird_id" "$signal_id")"
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Media/ name Media
	gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Media/ apps "$(variant_list "$spotify_id" "$vlc_id")"
}

apply_gnome_general_settings() {
	gsettings set org.gnome.mutter center-new-windows true
	gsettings set org.gnome.mutter dynamic-workspaces false
	gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
	gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
	gsettings set org.gnome.desktop.calendar show-weekdate true
	gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false
	gsettings set org.gnome.desktop.screensaver lock-enabled true
	gsettings set org.gnome.desktop.session idle-delay 0
	gsettings set org.gnome.desktop.input-sources xkb-options "['compose:caps']"
}

update_config() {
	command -v gsettings >/dev/null 2>&1 || return 0
	command -v gnome-extensions >/dev/null 2>&1 || return 0
	case "${XDG_CURRENT_DESKTOP:-}" in
		*GNOME*) ;;
		*)
			log_warn "Skipping GNOME config outside a GNOME desktop session."
			return 0
			;;
	esac

	apply_gnome_extensions
	apply_gnome_theme
	apply_gnome_keybindings
	apply_gnome_general_settings
	apply_gnome_app_layout
}
