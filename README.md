# Linux Setup

A tiered Debian/Ubuntu installer for CLI tools with optional personal config.
Pick a tier, optionally add a few extras, optionally apply the bundled shell,
tmux, and git configuration — interactively with [Gum](https://github.com/charmbracelet/gum)
or fully non-interactively for piped one-liners and automation.

## Install

Run the bootstrap with no arguments for an interactive run:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | bash
```

The bootstrap installs `ca-certificates`, `curl`, and `git`, clones the
repository to `~/.local/share/linux-setup`, installs the `linux-setup` launcher
in `~/.local/bin`, and forwards every argument to `setup.sh`. Re-running the
bootstrap updates or repairs the installation.

The launcher refreshes the existing checkout as the current user, then executes
the newly fetched `setup.sh`. It does not prepare packages or request sudo;
individual setup operations request elevated access only when they need it:

```bash
linux-setup
linux-setup desktop --config
linux-setup update agents
```

Pass arguments after `--` to run non-interactively. Install the essentials tier
without touching dotfiles:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | \
  bash -s -- essentials --no-config
```

Install essentials and apply personal config:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | \
  bash -s -- essentials --config \
  --name "Your Name" \
  --email "you@example.com"
```

Install the additive dev tier with Docker and native agent harnesses:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | \
  bash -s -- dev --with docker,agent-harnesses --no-config
```

## Tiers

Tiers are **additive layers** — each higher tier includes everything below it:

| Tier         | Includes                                  |
| ------------ | ----------------------------------------- |
| `essentials` | base CLI tools                            |
| `dev`        | essentials + developer tooling            |
| `desktop`    | essentials + dev + desktop GUI layer      |

### essentials

- git, GitHub CLI, curl, wget, and unzip
- ripgrep, fd-find, fzf, bat, eza, and zoxide
- btop, tmux, plocate, and fastfetch

GitHub CLI is installed from its signed apt repository. Fastfetch uses the
distro package when available and otherwise installs the official release
package, including on Ubuntu 24.04.

### dev

Everything in essentials, plus:

- mise from its signed apt repository
- global `python@latest`, `node@lts`, and `go@latest` runtimes
- Go build tools managed by mise: `gopls`, `dlv`, `staticcheck`, and
  `govulncheck`
- pipx and lazygit

### desktop

Everything in dev, plus a **desktop GUI layer**:

- **Brave Origin** — the minimalist standalone Brave build, from Brave's signed
  apt repository (`brave-origin`)
- **VS Code**, **Signal**, and **Spotify** — each from its own signed apt
  repository
- **Thunderbird**, **VLC**, **KeePassXC**, and **Alacritty** — from the distro
  apt repository
- **GNOME AppIndicator tray support** — enables tray/status icons in the top bar
  for apps and services such as Handy when they expose an AppIndicator,
  KStatusNotifierItem, or legacy tray icon, and installs the Ayatana
  AppIndicator runtime library for GTK-style apps
- **JetBrainsMono Nerd Font** — fetched from the
  [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) release and installed
  into `~/.local/share/fonts`

On Ubuntu the distro `thunderbird` package is a transitional shim that pulls the
snap, so the desktop layer installs Thunderbird from Mozilla's signed apt
repository (pinned above the Ubuntu archive) instead; Debian ships a genuine
`.deb`, so plain apt is used there.

Each component is installed in isolation: if one fails (for example a third-party
repository whose signing key has rotated or expired), it is rolled back so it
cannot poison `apt-get update` for the rest of the run, a warning is logged, and
setup continues. Anything skipped this way is listed in the closing recap.

**Brave Origin** is free on Linux but shows a one-time *Proceed with Origin for
free* prompt on first launch — complete it manually. When `--config` is enabled,
selected preferences are merged into the active Origin profile (see below).

## Extras

Extras are independent of the selected tier and are chosen with `--with`:

- `docker`: Docker Engine, Compose and Buildx plugins, plus lazydocker
- `ollama`: Ollama's official Linux installer
- `agent-harnesses`: Claude Code, Codex CLI, and Gemini CLI through their native
  or package-manager installers
- `startup-service`: a systemd **user** service that runs
  `~/.config/linux-setup/startup.sh` on every boot. The service unit is shipped
  in `configs/startup-service/`, but the startup script itself is generated once
  and left untracked so you can put machine-specific commands in it. Linger is
  enabled so it runs at boot without an interactive login.
- `yeet`: installs the `yeet` command (to `~/.local/bin`), which stages all
  changes, generates a commit message with an AI CLI, then commits and pushes.
  The backend is selected with `YEET_CLI` (`agy` by default, or `codex` /
  `claude`) and the model with `YEET_MODEL`. With shell config applied, a `yeet`
  alias is added too. Needs one of those CLIs installed.

Pass multiple extras as a comma-separated list, e.g. `--with docker,ollama`. Use
`--with none` to explicitly select no extras in a non-interactive run.
Interactive runs show a Gum checklist where zero or more extras can be selected.

## Personal config

With `--config`, the installer also installs and configures zsh, oh-my-zsh, the
bundled theme, tmux, the supplied git identity, and shared agent config. It sets
zsh as the default login shell and loads Oh My Zsh from `.zshrc` (managing a
clearly-delimited block that exports `~/.local/bin` on `PATH` and activates
mise). With `--no-config`, no dotfile or login-shell setting is modified.
The tmux config uses a Catppuccin Mocha-inspired native status line, truecolor,
OSC 52 clipboard forwarding, `Ctrl-a` as the primary prefix (`Ctrl-b` still
sends the prefix), current-directory splits, and TPM-managed plugins for sane
defaults, clipboard integration, and session restore.

When config is enabled, a git `--name` and `--email` are required (prompted for
interactively, or supplied via flags / environment variables). Interactive
prompts use the current global `git config user.name` and `user.email` as
editable defaults when those values are already set.

### Desktop config

When the desktop apps are present, `--config` also applies (each step is skipped
if its app is not installed):

- **Alacritty** — installs `configs/alacritty/alacritty.toml` to
  `~/.config/alacritty/alacritty.toml` (JetBrainsMono Nerd Font, padding,
  opacity).
- **VS Code** — installs `configs/vscode/settings.json` to
  `~/.config/Code/User/settings.json` and installs every extension listed in
  `configs/vscode/extensions.txt` (edit that file to match your stack).
- **Brave Origin** — merges `configs/brave/preferences.json` into the active
  profile's `Preferences` file after substituting your username into the download
  directory. Existing profile data and unrelated settings are preserved. The
  merge restores the last session, disables Sync and Brave's password manager,
  always shows the bookmarks bar, prompts for each download location, and keeps
  Origin's optional surfaces hidden. Brave must be closed while the merge runs.
  The config update removes the legacy `linux-setup.json` managed policy after a
  successful merge. It also installs user-local Brave Origin desktop-entry
  overrides with `StartupWMClass` values that match Brave's X11 window class, so
  GNOME can associate running browser windows with the correct Alt+Tab app, and
  makes stable Brave Origin the default browser for HTTP/HTTPS links and HTML
  files.
- **GNOME tray icons** — enables the packaged AppIndicator/KStatusNotifier
  extension when GNOME Shell is available and places 16px tray icons on the right
  side of the top bar. If icons do not appear immediately, log out and back in,
  then run `linux-setup update gnome-tray`.
- **Ulauncher** — installs the pinned official Ulauncher release, applies the
  current search shortcuts and Liquid Glass themes, configures Wayland
  autostart, and clones the private Brave tab-search bridge into
  `~/.local/share/brave-tab-search`. Configured desktop installs fail before
  making changes when that private repository is not accessible over SSH.
- **GNOME desktop** — applies the Tokyo Night/Yaru appearance, six-workspace
  layout, keyboard shortcuts, favourites, app folders, and settings for any
  supported Shell extensions already installed. Missing optional extensions
  are reported for installation through Extension Manager.

Direct profile preferences do not force-install extensions or manage search
engines. Install and pin uBlock Origin through Brave itself, and configure the
default and site-search engines in `brave://settings/searchEngines`.

### Agent config

Agent files are stored under `configs/agents/`:

- `configs/agents/AGENTS.md` is the canonical global instruction source. It is
  installed as `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`, so both agents
  receive identical instructions.
- `configs/agents/skills/` is the shared custom skill source and is installed to
  both `~/.codex/skills` and `~/.claude/skills`.
- `configs/agents/codex/config.toml` is installed to `~/.codex/config.toml`.
- `configs/agents/claude/settings.json` is installed to `~/.claude/settings.json`.
- `configs/agents/claude/statusline-command.sh` is installed to
  `~/.claude/statusline-command.sh`.

Each repository skill is linked into both agents' skill directories. Updating
reconciles those links: new skills are added, removed repository skills are
unlinked, and same-named local paths are replaced. Unrelated skills, including
Codex's `.system` directory, are left alone.

Repository-owned config is authoritative. Reapplying it replaces the managed
target without creating timestamped backups. Mixed files such as `.zshrc` and
Brave's `Preferences` retain their unrelated local content because setup edits
only its settings or merges selected values.

## Update config

The update command first refreshes the checkout in
`~/.local/share/linux-setup`, then applies only the requested targets:

```bash
linux-setup update agents
linux-setup update zsh tmux
linux-setup update all
```

Multiple space-separated targets work too. `update-config` remains an alias for
older installed shell helpers.

| Target | Managed configuration |
| --- | --- |
| `agents` | Codex and Claude settings, global instructions, and all shared skills |
| `zsh`, `tmux`, `alacritty`, `vscode`, `brave`, `ulauncher`, `gnome`, `gnome-tray` | The named application or desktop config |
| `startup-service` | The systemd user unit, when the extra is already installed |
| `yeet` | The `yeet` command in `~/.local/bin` |
| `all` | Every discovered component |

Targets are discovered rather than maintained in a central list. Every direct
child of `configs/` that contains an `update.sh` is an update target; the folder
name is its CLI name. Each component defines an `update_config` function and
whether it participates in a normal `--config` installation. `configs/manual/`
has no updater and is deliberately excluded. Consequently, adding a new target
requires only a new component directory—no CLI dispatch code needs changing.

## CLI reference

```
Usage: setup.sh [essentials|dev|desktop] [options]
       setup.sh update [TARGET[,TARGET...]] [options]

Options:
  --config              Apply personal shell, tmux, git, app, and agent config
  --no-config           Install tools without touching dotfiles
  --name NAME           Git user.name (used with --config)
  --email EMAIL         Git user.email (used with --config)
  --with EXTRAS         Comma-separated: docker,ollama,agent-harnesses,startup-service,yeet
                        Use --with none to explicitly select no extras
  -h, --help            Show this help
```

## Configuration precedence

Each choice is resolved from **command-line arguments first, then environment
variables, then an interactive Gum prompt**:

| Setting        | Flag                  | Environment variable     |
| -------------- | --------------------- | ------------------------ |
| Tier           | positional argument   | `LINUX_SETUP_TIER`       |
| Extras         | `--with`              | `LINUX_SETUP_EXTRAS`     |
| Config on/off  | `--config`/`--no-config` | `LINUX_SETUP_CONFIG`  |
| Update targets | positional after `update` | `LINUX_SETUP_UPDATE_CONFIGS` |
| Git name       | `--name`              | `LINUX_SETUP_FULL_NAME`  |
| Git email      | `--email`             | `LINUX_SETUP_EMAIL`      |

`LINUX_SETUP_CONFIG` accepts `yes/no`, `true/false`, or `1/0`.

```bash
LINUX_SETUP_TIER=essentials \
LINUX_SETUP_EXTRAS=docker,ollama \
LINUX_SETUP_CONFIG=yes \
LINUX_SETUP_FULL_NAME="Your Name" \
LINUX_SETUP_EMAIL="you@example.com" \
bash setup.sh
```

The bootstrap (`install.sh`) additionally honors `LINUX_SETUP_REPO_URL`,
`LINUX_SETUP_REPO_REF`, and `LINUX_SETUP_INSTALL_DIR` to control where the
repository is fetched from and cloned to.

### Interactive flow

When run from a terminal with no values supplied, setup:

1. Installs Gum if it is missing.
2. Asks whether to install software or update config.
3. For an install, asks for the tier, extras, and optional personal config.
4. For an update, shows a checklist of config targets.
5. Shows a preflight summary and asks for confirmation before making changes.

A non-interactive install (piped input, no TTY) requires at least a tier and a
config choice up front. A non-interactive update requires at least one target.

Refresh the complete agent bundle from an existing checkout:

```bash
linux-setup update agents
```

## Local development

Run setup directly from a checkout:

```bash
bash setup.sh essentials --no-config
```

Lint the shell scripts the same way CI does:

```bash
shellcheck -x $(git ls-files '*.sh')
bash tests/config-update.sh
bash tests/gnome-config.sh
bash tests/launcher.sh
bash tests/ulauncher-config.sh
```

A GitHub Actions workflow (`.github/workflows/shellcheck.yml`) runs the lint and
configuration tests on every push and pull request.

## Testing in a VM (virt-manager + snapshots)

The cleanest way to test the installer end-to-end is a throwaway Debian/Ubuntu
VM under [virt-manager](https://virt-manager.org/) (libvirt/KVM). Install the
OS once, take a **clean snapshot**, run the installer, then **restore the
snapshot** to retest from a pristine system as many times as you like.

### 1. Install virtualization tooling

```bash
sudo apt install -y virt-manager qemu-system-x86 libvirt-daemon-system
sudo usermod -aG libvirt "$USER"   # log out and back in for this to take effect
```

### 2. Create a VM

Download an installer image:

- Debian: the amd64 **netinst** image from <https://www.debian.org/CD/netinst/>
- Ubuntu: a Desktop or Server ISO from <https://ubuntu.com/download>

Create the VM from the ISO, either through the virt-manager GUI
(*File → New Virtual Machine → Local install media*) or with `virt-install`:

```bash
virt-install \
  --name linux-setup-test \
  --memory 4096 \
  --vcpus 2 \
  --disk size=64 \
  --cdrom ~/Downloads/debian-13.0.0-amd64-netinst.iso \
  --os-variant debian13 \
  --graphics spice
```

For Ubuntu, swap in the Ubuntu ISO and `--os-variant ubuntu24.04`. Run
`virt-install --osinfo list` to find the exact variant name for your release.

Complete the OS installation, creating a user with sudo privileges.

### 3. Take a clean snapshot

Shut the guest down so the snapshot captures a quiescent disk, then snapshot it:

```bash
virsh shutdown linux-setup-test
virsh snapshot-create-as linux-setup-test --name clean --description "Clean OS install"
```

You can also use the virt-manager GUI: open the VM, click the snapshots
(camera) icon, and create a snapshot named `clean`.

### 4. Run the installer

Boot the VM and run the installer inside it, either from the published
one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | bash
```

or from a local checkout to test in-progress changes:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/paulrauchbach/linux-setup.git
cd linux-setup
LINUX_SETUP_INSTALL_DIR="$(pwd)" bash setup.sh
```

### 5. Restore and retest

To repeat the test from a clean system, revert to the snapshot and boot again:

```bash
virsh snapshot-revert linux-setup-test --snapshotname clean
virsh start linux-setup-test
```

(The snapshots panel in the virt-manager GUI offers the same revert action.)
