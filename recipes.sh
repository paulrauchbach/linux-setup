#!/usr/bin/env bash

MISE_PREPARED=0

install_gum() {
	if command -v gum >/dev/null 2>&1; then
		return 0
	fi

	is_supported_platform ||
		die "gum is required for interactive setup; automatic installation supports Debian and Ubuntu only."

	apt_update
	if apt-cache show gum >/dev/null 2>&1; then
		apt_install gum
	else
		add_signed_apt_repo \
			"Charm" \
			"https://repo.charm.sh/apt/gpg.key" \
			"/etc/apt/keyrings/charm.asc" \
			"deb [signed-by=/etc/apt/keyrings/charm.asc] https://repo.charm.sh/apt/ * *" \
			"/etc/apt/sources.list.d/charm.list"
		apt_install gum
	fi

	command -v gum >/dev/null 2>&1 || die "gum installation completed but the command is unavailable."
}

install_github_cli() {
	local architecture

	is_supported_platform || {
		log_warn "Skipping GitHub CLI on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	architecture="$(dpkg --print-architecture)"
	add_signed_apt_repo \
		"GitHub CLI" \
		"https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
		"/etc/apt/keyrings/githubcli-archive-keyring.gpg" \
		"deb [arch=$architecture signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		"/etc/apt/sources.list.d/github-cli.list"
	apt_install gh
}

install_fastfetch() {
	local architecture
	local package_file
	local package_url

	if command -v fastfetch >/dev/null 2>&1; then
		return 0
	fi

	is_supported_platform || {
		log_warn "Skipping Fastfetch on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	if apt-cache show fastfetch >/dev/null 2>&1; then
		apt_install fastfetch
		return 0
	fi

	architecture="$(dpkg --print-architecture)"
	case "$architecture" in
		amd64)
			architecture="amd64"
			;;
		arm64)
			architecture="aarch64"
			;;
		*)
			die "Unsupported architecture for Fastfetch: $architecture"
			;;
	esac

	package_file="$(mktemp --suffix=.deb)"
	package_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${architecture}.deb"

	run_quiet "Downloading Fastfetch" curl -fsSL "$package_url" -o "$package_file"
	run_quiet "Installing Fastfetch" sudo apt-get install -y -qq "$package_file"
	rm -f "$package_file"
}

install_mise() {
	if [ "$MISE_PREPARED" -eq 1 ]; then
		return 0
	fi

	is_supported_platform || {
		log_warn "Skipping mise on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	add_signed_apt_repo \
		"mise" \
		"https://mise.en.dev/gpg-key.pub" \
		"/etc/apt/keyrings/mise-archive-keyring.asc" \
		"deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.en.dev/deb stable main" \
		"/etc/apt/sources.list.d/mise.list"
	apt_install mise

	command -v mise >/dev/null 2>&1 || die "mise installation completed but the command is unavailable."
	MISE_PREPARED=1
}

install_mise_defaults() {
	install_mise
	command -v mise >/dev/null 2>&1 || return 0
	run_quiet "Installing default Python with mise" mise use --global python@latest
	run_quiet "Installing default Node.js with mise" mise use --global node@lts
}

install_lazygit() {
	local version
	local architecture
	local archive
	local archive_url
	local extract_dir

	is_supported_platform || {
		log_warn "Skipping lazygit on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	if apt-cache show lazygit >/dev/null 2>&1; then
		apt_install lazygit
		return 0
	fi

	architecture="$(uname -m)"
	case "$architecture" in
		x86_64)
			architecture="x86_64"
			;;
		aarch64 | arm64)
			architecture="arm64"
			;;
		*)
			die "Unsupported architecture for lazygit: $architecture"
			;;
	esac

	version="$(
		curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
			sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' |
			head -n 1
	)"
	[ -n "$version" ] || die "Could not determine the latest lazygit version."

	archive="$(mktemp)"
	extract_dir="$(mktemp -d)"
	archive_url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${architecture}.tar.gz"

	run_quiet "Downloading lazygit $version" curl -fsSL "$archive_url" -o "$archive"
	run_quiet "Extracting lazygit" tar -xzf "$archive" -C "$extract_dir" lazygit
	run_quiet "Installing lazygit" sudo install -m 0755 "$extract_dir/lazygit" /usr/local/bin/lazygit

	rm -f "$archive" "$extract_dir/lazygit"
	rmdir "$extract_dir"
}

install_lazydocker() {
	run_remote_script \
		"lazydocker" \
		"https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh"
}

install_docker() {
	local architecture
	local docker_source
	local user_name

	is_supported_platform || {
		log_warn "Skipping Docker on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	[ -n "$LINUX_SETUP_OS_CODENAME" ] || die "Could not determine the OS codename for Docker."
	architecture="$(dpkg --print-architecture)"
	docker_source="Types: deb
URIs: https://download.docker.com/linux/$LINUX_SETUP_OS_ID
Suites: $LINUX_SETUP_OS_CODENAME
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc"

	add_signed_apt_repo \
		"Docker" \
		"https://download.docker.com/linux/$LINUX_SETUP_OS_ID/gpg" \
		"/etc/apt/keyrings/docker.asc" \
		"$docker_source" \
		"/etc/apt/sources.list.d/docker.sources"

	apt_install \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin

	user_name="$(id -un)"
	run_quiet "Adding $user_name to the docker group" sudo usermod -aG docker "$user_name"
	install_lazydocker
}

install_ollama() {
	run_remote_script "Ollama" "https://ollama.com/install.sh" sh
}

install_claude() {
	run_remote_script "Claude Code" "https://claude.ai/install.sh"
}

install_node_clis() {
	local node_apps=(
		pnpm
		@openai/codex
		@google/gemini-cli
	)
	local app

	install_mise
	command -v mise >/dev/null 2>&1 || return 0
	run_quiet "Ensuring Node.js is available" mise use --global node@lts

	for app in "${node_apps[@]}"; do
		run_quiet "Installing $app" mise exec node@lts -- npm install --global "$app"
	done
}

install_vscode() {
	is_supported_platform || {
		log_warn "Skipping VS Code on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	add_signed_apt_repo \
		"Visual Studio Code" \
		"https://packages.microsoft.com/keys/microsoft.asc" \
		"/etc/apt/keyrings/microsoft.asc" \
		"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main" \
		"/etc/apt/sources.list.d/vscode.list"
	apt_install code
}

install_signal() {
	is_supported_platform || {
		log_warn "Skipping Signal on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	add_signed_apt_repo \
		"Signal" \
		"https://updates.signal.org/desktop/apt/keys.asc" \
		"/etc/apt/keyrings/signal-desktop-keyring.asc" \
		"deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop-keyring.asc] https://updates.signal.org/desktop/apt xenial main" \
		"/etc/apt/sources.list.d/signal-xenial.list"
	apt_install signal-desktop
}

install_spotify() {
	is_supported_platform || {
		log_warn "Skipping Spotify on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	add_signed_apt_repo \
		"Spotify" \
		"https://download.spotify.com/debian/pubkey_0D811D58.gpg" \
		"/etc/apt/keyrings/spotify.gpg" \
		"deb [arch=amd64 signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free" \
		"/etc/apt/sources.list.d/spotify.list"
	apt_install spotify-client
}

install_thunderbird() {
	local pref_tmp

	is_supported_platform || {
		log_warn "Skipping Thunderbird on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	# Ubuntu's distro 'thunderbird' is a transitional package that pulls the
	# snap, so install from Mozilla's signed apt repository (pinned above the
	# Ubuntu archive) instead. Debian ships a genuine .deb, so plain apt is
	# enough there.
	if [ "$LINUX_SETUP_OS_ID" = "ubuntu" ]; then
		add_signed_apt_repo \
			"Mozilla" \
			"https://packages.mozilla.org/apt/repo-signing-key.gpg" \
			"/etc/apt/keyrings/packages.mozilla.org.asc" \
			"deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
			"/etc/apt/sources.list.d/mozilla.list"

		pref_tmp="$(mktemp)"
		printf '%s\n' \
			"Package: *" \
			"Pin: origin packages.mozilla.org" \
			"Pin-Priority: 1000" >"$pref_tmp"
		run_quiet "Pinning the Mozilla apt repository" \
			sudo install -D -m 0644 "$pref_tmp" /etc/apt/preferences.d/mozilla
		rm -f "$pref_tmp"
		apt_update yes
	fi

	apt_install thunderbird
}

install_brave() {
	local architecture
	local brave_source

	is_supported_platform || {
		log_warn "Skipping Brave Origin on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	architecture="$(dpkg --print-architecture)"
	brave_source="Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: $architecture
Signed-By: /etc/apt/keyrings/brave-browser-archive-keyring.gpg"

	add_signed_apt_repo \
		"Brave" \
		"https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
		"/etc/apt/keyrings/brave-browser-archive-keyring.gpg" \
		"$brave_source" \
		"/etc/apt/sources.list.d/brave-browser.sources"
	apt_install brave-origin
}

install_nerd_font() {
	local font_name="JetBrainsMono"
	local font_label="JetBrainsMono Nerd Font"
	local font_dir="$HOME/.local/share/fonts/${font_name}NerdFont"
	local archive
	local archive_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

	if command -v fc-list >/dev/null 2>&1 && fc-list | grep -qiF "$font_label"; then
		return 0
	fi

	apt_install fontconfig

	archive="$(mktemp --suffix=.zip)"
	run_quiet "Downloading $font_label" curl -fsSL "$archive_url" -o "$archive"
	mkdir -p "$font_dir"
	run_quiet "Extracting $font_label" unzip -o -q "$archive" -d "$font_dir"
	rm -f "$archive"

	if command -v fc-cache >/dev/null 2>&1; then
		run_quiet "Refreshing the font cache" fc-cache -f "$font_dir"
	fi
}

install_desktop() {
	is_supported_platform || {
		log_warn "Skipping desktop GUI apps on unsupported platform '$LINUX_SETUP_OS_ID'."
		return 0
	}

	if [ "$#" -gt 0 ]; then
		apt_install "$@"
	fi

	install_thunderbird
	install_vscode
	install_signal
	install_spotify
	install_brave
	install_nerd_font
}

install_extras() {
	local extras="$1"
	local selected=()
	local extra

	IFS=',' read -r -a selected <<<"$extras"
	for extra in "${selected[@]}"; do
		case "$extra" in
			docker)
				install_docker
				;;
			ollama)
				install_ollama
				;;
			claude)
				install_claude
				;;
			node-clis)
				install_node_clis
				;;
		esac
	done
}
