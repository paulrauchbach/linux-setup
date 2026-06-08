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
