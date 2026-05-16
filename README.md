# Linux Setup

Bare-bones CLI setup for Debian-based Linux systems.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | bash
```

The installer clones this repository to `~/.local/share/linux-setup` and runs the setup from there.

For a non-interactive install:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | \
  CONFIG_FULL_NAME="Your Name" CONFIG_EMAIL="you@example.com" bash
```

## What It Installs

- zsh
- oh-my-zsh with custom theme and plugins
- tmux config
- common CLI tools
- Docker
- GitHub CLI
- mise with Python and Node
- lazydocker
- Ollama
- Claude Code
- global Node CLI tools

## Local Development

Run the local checkout directly:

```bash
LINUX_SETUP_REPO_URL="$(pwd)" bash install.sh
```

Or run setup from the current checkout:

```bash
LINUX_SETUP_INSTALL_DIR="$(pwd)" bash setup.sh
```
