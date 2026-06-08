# Linux Setup

A tiered Debian/Ubuntu installer for CLI tools with optional personal config.

## Install

Interactive:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | bash
```

Install the essentials tier without touching dotfiles:

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

Install the additive dev tier with Docker and the Node CLI bundle:

```bash
curl -fsSL https://raw.githubusercontent.com/paulrauchbach/linux-setup/main/install.sh | \
  bash -s -- dev --with docker,node-clis --no-config
```

The bootstrap installs `ca-certificates`, `curl`, and `git`, clones the repository
to `~/.local/share/linux-setup`, and forwards every argument to `setup.sh`.

## Essentials

The essentials tier installs:

- git, GitHub CLI, curl, wget, and unzip
- ripgrep, fd-find, fzf, bat, eza, and zoxide
- btop, tmux, plocate, and fastfetch

GitHub CLI is installed from its signed apt repository.

## Dev

The dev tier includes everything in essentials and adds:

- mise from its signed apt repository
- global `python@latest` and `node@lts` runtimes
- pipx and lazygit

## Extras

Extras are independent of the selected tier:

- `docker`: Docker Engine, Compose and Buildx plugins, plus lazydocker
- `ollama`: Ollama's official Linux installer
- `claude`: Claude Code's native installer
- `node-clis`: pnpm, Codex CLI, and Gemini CLI through mise-managed Node.js

Pass multiple extras as a comma-separated list. Interactive runs show a Gum
checklist where zero or more extras can be selected.

With config enabled, the installer also installs and configures zsh, oh-my-zsh,
the bundled theme, tmux, and the supplied git identity. With config disabled,
no dotfile is modified.

The `desktop` tier is reserved for a later slice and currently exits with a
clear "not yet available" message.

## Configuration

Each choice uses command-line arguments first, then environment variables, then
an interactive Gum prompt:

```bash
LINUX_SETUP_TIER=essentials \
LINUX_SETUP_EXTRAS=docker,ollama \
LINUX_SETUP_CONFIG=yes \
LINUX_SETUP_FULL_NAME="Your Name" \
LINUX_SETUP_EMAIL="you@example.com" \
bash setup.sh
```

Use `bash setup.sh --help` for all supported flags.

## Local Development

Run setup from the current checkout:

```bash
bash setup.sh essentials --no-config
```

### Test in a VM with Quickemu

Install the required tools and create a directory for test VMs:

```bash
sudo apt install quickemu qemu-utils cloud-image-utils
mkdir -p ~/VMs/linux-setup-tests
cd ~/VMs/linux-setup-tests
```

#### Ubuntu Minimal

Ubuntu provides a small, preinstalled cloud image instead of a minimal installer ISO. Download the Ubuntu 24.04 LTS minimal image and expand its virtual disk to 64 GB:

```bash
mkdir -p ubuntu-test
curl -fL \
  -o ubuntu-test/disk.qcow2 \
  https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
qemu-img resize ubuntu-test/disk.qcow2 64G
```

Cloud images use cloud-init for initial user setup. Create a test user:

```bash
cat > ubuntu-test/user-data <<'EOF'
#cloud-config
users:
  - name: ubuntu
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
chpasswd:
  expire: false
  users:
    - name: ubuntu
      password: ubuntu
      type: text
ssh_pwauth: true
EOF
```

Create the cloud-init seed and `ubuntu-test.conf`:

```bash
printf 'instance-id: ubuntu-test\nlocal-hostname: ubuntu-test\n' > ubuntu-test/meta-data
cloud-localds ubuntu-test/seed.iso ubuntu-test/user-data ubuntu-test/meta-data

cat > ubuntu-test.conf <<'EOF'
#!/usr/bin/quickemu --vm
guest_os="linux"
disk_img="ubuntu-test/disk.qcow2"
iso="ubuntu-test/seed.iso"
EOF
```

Start the VM and log in with username `ubuntu` and password `ubuntu`:

```bash
quickemu --vm ubuntu-test.conf
```

The root filesystem should automatically expand to the 64 GB virtual disk during the first boot.

#### Debian Netinst

Download the official amd64 **netinst** image from [debian.org](https://www.debian.org/CD/netinst/) and save it as `debian-test/debian-netinst.iso`. Netinst contains only the installer and a basic package set; remaining packages are downloaded during installation.

Create a 64 GB virtual disk:

```bash
mkdir -p debian-test
mv ~/Downloads/debian-*-amd64-netinst.iso debian-test/debian-netinst.iso
qemu-img create -f qcow2 debian-test/disk.qcow2 64G
```

Create `debian-test.conf`:

```bash
cat > debian-test.conf <<'EOF'
#!/usr/bin/quickemu --vm
guest_os="linux"
disk_img="debian-test/disk.qcow2"
iso="debian-test/debian-netinst.iso"
EOF
```

Start the VM and install Debian:

```bash
quickemu --vm debian-test.conf
```

#### Test the Setup

After the first boot or installation, shut down the guest and create a clean snapshot:

```bash
VM=ubuntu-test.conf # or debian-test.conf
quickemu --vm "$VM" --snapshot create clean-install
```

Clone the repository inside the VM and run the installer:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/paulrauchbach/linux-setup.git
cd linux-setup
LINUX_SETUP_INSTALL_DIR="$(pwd)" bash setup.sh
```

To repeat the test from a clean system, shut down the VM and restore the snapshot:

```bash
VM=ubuntu-test.conf # or debian-test.conf
quickemu --vm "$VM" --snapshot apply clean-install
quickemu --vm "$VM"
```
