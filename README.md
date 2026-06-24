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
repository to `~/.local/share/linux-setup`, and forwards every argument to
`setup.sh`. Re-running it updates the existing checkout in place.

With zsh config applied, a `linux-setup` helper is also added to `.zshrc`. It
runs the bootstrap command above and forwards arguments, so these are equivalent
to the curl examples:

```bash
linux-setup
linux-setup desktop --config
linux-setup update-config vscode
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
- global `python@latest` and `node@lts` runtimes
- pipx and lazygit

### desktop

Everything in dev, plus a **desktop GUI layer**:

- **Brave Origin** — the minimalist standalone Brave build, from Brave's signed
  apt repository (`brave-origin`)
- **VS Code**, **Signal**, and **Spotify** — each from its own signed apt
  repository
- **Thunderbird**, **VLC**, **KeePassXC**, and **Alacritty** — from the distro
  apt repository
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
a managed browser policy is installed (see below).

## Extras

Extras are independent of the selected tier and are chosen with `--with`:

- `docker`: Docker Engine, Compose and Buildx plugins, plus lazydocker
- `ollama`: Ollama's official Linux installer
- `claude`: Claude Code's native installer
- `agent-harnesses`: Codex CLI, Pi Coding Agent, Antigravity CLI, and OpenCode
  through their native installers
- `startup-service`: a systemd **user** service that runs
  `~/.config/linux-setup/startup.sh` on every boot. The service unit is shipped
  in `configs/`, but the startup script itself is generated once and left
  untracked so you can put machine-specific commands in it. Linger is enabled so
  it runs at boot without an interactive login.
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
bundled theme, tmux, and the supplied git identity. It sets zsh as the default
login shell and loads Oh My Zsh from `.zshrc` (managing a clearly-delimited
block that exports `~/.local/bin` on `PATH` and activates mise). With
`--no-config`, no dotfile or login-shell setting is modified.

When config is enabled, a git `--name` and `--email` are required (prompted for
interactively, or supplied via flags / environment variables). Interactive
prompts use the current global `git config user.name` and `user.email` as
editable defaults when those values are already set.

### Desktop config

When the desktop apps are present, `--config` also applies (each step is skipped
if its app is not installed):

- **Alacritty** — installs `configs/alacritty.toml` to
  `~/.config/alacritty/alacritty.toml` (JetBrainsMono Nerd Font, padding,
  opacity).
- **VS Code** — installs `configs/vscode-settings.json` to
  `~/.config/Code/User/settings.json` and installs every extension listed in
  `configs/vscode-extensions.txt` (edit that file to match your stack).
- **Brave Origin** — renders `configs/brave-policy.json` (substituting your
  username into the download directory) and installs it as a root-owned managed
  policy at `/etc/brave/policies/managed/linux-setup.json`. It restores the last
  session, disables sync/metrics/password-manager/News/Rewards/Wallet/VPN/Talk/Tor,
  prompts for each download location, sets DuckDuckGo as default search,
  force-installs and pins uBlock Origin, and adds `debian` and `perplexity`
  site-search shortcuts.

After installing Brave Origin, restart it and verify the policy at
`brave://policy`. The Brave-specific keys are best-effort and should be checked
there in a clean VM — adjust any that the build flags as unrecognized. Chromium
has no equivalent of Firefox's `SearchEngines.Remove`, so bundled search
providers are not removed.

## CLI reference

```
Usage: setup.sh [essentials|dev|desktop] [options]

Options:
  --config              Apply personal shell, tmux, and git config
  --no-config           Install tools without touching dotfiles
  --name NAME           Git user.name (used with --config)
  --email EMAIL         Git user.email (used with --config)
  --with EXTRAS         Comma-separated: docker,ollama,claude,agent-harnesses,startup-service,yeet
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

When run from a terminal with no values supplied, the installer:

1. Installs Gum if it is missing.
2. Asks you to choose a tier.
3. Shows a checklist of optional extras (space to toggle, zero or more).
4. Asks whether to apply personal config; if yes, prompts for git name and email.
5. Shows a preflight summary box and asks for confirmation before making changes.
6. Installs the selected tier, extras, and config, then prints a recap box.

A non-interactive run (piped input, no TTY) requires at least a tier and a
config choice up front, since there is nowhere to prompt.

## Local development

Run setup directly from a checkout:

```bash
bash setup.sh essentials --no-config
```

Lint the shell scripts the same way CI does:

```bash
shellcheck -x $(git ls-files '*.sh')
```

A GitHub Actions workflow (`.github/workflows/shellcheck.yml`) runs the same
shellcheck pass on every push and pull request.

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
