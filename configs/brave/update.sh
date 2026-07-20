#!/usr/bin/env bash

export LINUX_SETUP_APPLY_DURING_INSTALL=yes

merge_json_preferences() {
	local source_preferences="$1"
	local target_preferences="$2"
	local merged
	local target_dir

	target_dir="$(dirname "$target_preferences")"
	mkdir -p "$target_dir"
	merged="$(mktemp "$target_dir/.linux-setup-preferences.XXXXXX")"

	if [ -f "$target_preferences" ]; then
		jq -c -s '.[0] * .[1]' "$target_preferences" "$source_preferences" >"$merged" || {
			rm -f "$merged"
			die "Could not merge preferences into $target_preferences."
		}
	else
		jq -c . "$source_preferences" >"$merged" || {
			rm -f "$merged"
			die "Invalid preferences in $source_preferences."
		}
	fi

	if [ -f "$target_preferences" ] &&
		jq -e -s '.[0] == .[1]' "$merged" "$target_preferences" >/dev/null; then
		rm -f "$merged"
		log_success "$target_preferences is already up to date"
		return 0
	fi

	run_quiet "Updating $target_preferences" mv "$merged" "$target_preferences"
}

remove_legacy_brave_policy() {
	local target_policy="/etc/brave/policies/managed/linux-setup.json"

	[ -e "$target_policy" ] || return 0

	require_sudo
	run_quiet "Removing legacy Brave managed policy" sudo rm -f "$target_policy"
}

apply_brave_preferences() {
	local source_preferences="$LINUX_SETUP_COMPONENT_DIR/preferences.json"
	local user_data_dir="$HOME/.config/BraveSoftware/Brave-Origin"
	local local_state="$user_data_dir/Local State"
	local profile_name="Default"
	local target_preferences
	local user_name
	local rendered

	if ! command -v brave-browser >/dev/null 2>&1 &&
		! command -v brave >/dev/null 2>&1 &&
		! { command -v dpkg >/dev/null 2>&1 && dpkg -s brave-origin >/dev/null 2>&1; }; then
		return 0
	fi

	[ -f "$source_preferences" ] || die "Brave preferences not found at $source_preferences."
	command -v jq >/dev/null 2>&1 || die "jq is required to merge Brave preferences."

	if pgrep -f '^/opt/brave.com/brave-origin/brave( |$)' >/dev/null 2>&1; then
		log_warn "Skipping Brave preferences while Brave Origin is running. Close it and run 'linux-setup update brave'."
		return 0
	fi

	if [ -f "$local_state" ]; then
		profile_name="$(jq -r '.profile.last_used // "Default"' "$local_state")"
	fi
	case "$profile_name" in
		"" | */* | .* | *..*)
			die "Invalid Brave profile name '$profile_name' in $local_state."
			;;
	esac
	target_preferences="$user_data_dir/$profile_name/Preferences"

	user_name="$(id -un)"
	rendered="$(mktemp)"
	sed "s|__USER_NAME__|$user_name|g" "$source_preferences" >"$rendered"
	merge_json_preferences "$rendered" "$target_preferences"
	rm -f "$rendered"
	remove_legacy_brave_policy
}

apply_brave_desktop_integration() {
	local target_dir="$HOME/.local/share/applications"
	local entries=(
		"/usr/share/applications/brave-origin.desktop:brave-origin"
		"/usr/share/applications/com.brave.Origin.desktop:brave-origin"
		"/usr/share/applications/brave-origin-beta.desktop:brave-origin-beta"
		"/usr/share/applications/com.brave.Origin.beta.desktop:brave-origin-beta"
	)
	local entry
	local source_entry
	local wm_class
	local rendered

	if ! command -v brave-origin-stable >/dev/null 2>&1 &&
		! command -v brave-origin-beta >/dev/null 2>&1 &&
		! { command -v dpkg >/dev/null 2>&1 && dpkg -s brave-origin >/dev/null 2>&1; }; then
		return 0
	fi

	mkdir -p "$target_dir"

	for entry in "${entries[@]}"; do
		source_entry="${entry%%:*}"
		wm_class="${entry#*:}"

		[ -f "$source_entry" ] || continue

		rendered="$(mktemp)"
		awk -v wm_class="$wm_class" '
			BEGIN { in_entry = 0; inserted = 0 }
			/^\[Desktop Entry\]$/ { in_entry = 1 }
			in_entry && /^StartupWMClass=/ {
				print "StartupWMClass=" wm_class
				inserted = 1
				next
			}
			in_entry && /^Type=Application$/ && !inserted {
				print
				print "StartupWMClass=" wm_class
				inserted = 1
				next
			}
			{ print }
			END {
				if (!inserted) {
					print "StartupWMClass=" wm_class
				}
			}
		' "$source_entry" >"$rendered"

		install_config_file "$rendered" "$target_dir/$(basename "$source_entry")"
		rm -f "$rendered"
	done
}

set_brave_as_default_browser() {
	local desktop_id=""
	local candidate
	local mime_type

	for candidate in brave-origin.desktop com.brave.Origin.desktop; do
		if [ -f "$HOME/.local/share/applications/$candidate" ] ||
			[ -f "/usr/share/applications/$candidate" ]; then
			desktop_id="$candidate"
			break
		fi
	done

	if [ -z "$desktop_id" ]; then
		log_warn "Skipping default browser configuration: no stable Brave Origin desktop entry was found."
		return 0
	fi
	if ! command -v xdg-settings >/dev/null 2>&1 ||
		! command -v xdg-mime >/dev/null 2>&1; then
		log_warn "Skipping default browser configuration: xdg-utils is not installed."
		return 0
	fi

	run_quiet "Setting Brave Origin as the default browser" \
		xdg-settings set default-web-browser "$desktop_id"
	for mime_type in x-scheme-handler/http x-scheme-handler/https text/html; do
		run_quiet "Associating $mime_type with Brave Origin" \
			xdg-mime default "$desktop_id" "$mime_type"
	done
}

update_config() {
	apply_brave_preferences
	apply_brave_desktop_integration
	set_brave_as_default_browser
}
