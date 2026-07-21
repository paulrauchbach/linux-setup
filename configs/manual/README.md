# Personal GNOME setup

This is the detailed design reference for the GNOME configuration automated by
`configs/gnome/update.sh` and `configs/ulauncher/update.sh`. A configured
`desktop` tier run applies it; use `linux-setup update gnome,ulauncher` to
reapply it later. It adapts the GNOME configuration from Omakub to the
applications installed by this setup.

An agent following this document should apply the configuration, not merely
describe it. Run user-level commands as the logged-in desktop user. Use `sudo`
only for apt, repository, and GLib schema operations. The commands are intended
for Ubuntu 24.04 or newer and should be safe to run more than once.

## Desired result

- Tokyo Night-flavoured Yaru theme with a purple accent and matching wallpaper.
- Six fixed workspaces.
- Omakub's window-management, workspace, launcher, terminal, browser, and
  screenshot shortcuts.
- Tactile, Just Perfection, Blur My Shell, Space Bar, Undecorate, TopHat, and
  Alphabetical App Grid extensions.
- AppIndicator remains enabled because `linux-setup` installs it for tray icons.
- Ubuntu Dock, Desktop Icons NG, and Ubuntu Tiling Assistant are disabled.
- The GNOME overview favourites match the desktop apps installed by
  `linux-setup`: Brave Origin, Alacritty, VS Code, Thunderbird, Signal, Spotify,
  KeePassXC, Files, and Settings.
- The app grid groups development, communication, and media apps. It does not
  delete distro-provided `.desktop` files.

## 1. Preconditions and packages

First confirm that this is a GNOME session:

```bash
case "${XDG_CURRENT_DESKTOP:-}" in
  *GNOME*) ;;
  *) echo "This runbook requires a GNOME session" >&2; exit 1 ;;
esac
```

The normal `linux-setup desktop --config` run already installs Alacritty,
Brave Origin, VS Code, Thunderbird, Signal, Spotify, VLC, KeePassXC,
JetBrainsMono Nerd Font, and the packaged AppIndicator extension. Install the
remaining GNOME and shortcut dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
  flameshot \
  gir1.2-clutter-1.0 \
  gir1.2-gtop-2.0 \
  gnome-shell-extension-appindicator \
  gnome-shell-extension-manager \
  gnome-sushi \
  gnome-tweaks \
  software-properties-common \
  yaru-theme-gtk \
  yaru-theme-icon

# linux-setup installs a pinned, checksum-verified official Ulauncher .deb.
```

GNOME Sushi provides spacebar previews in Files. GNOME Tweaks and Extension
Manager are installed as manual control panels.

Configure Ulauncher to start in the Wayland session. Ulauncher's own hotkey is
left disabled because GNOME owns `Super+Space` below.

```bash
mkdir -p "$HOME/.config/autostart"
cat >"$HOME/.config/autostart/ulauncher.desktop" <<'EOF'
[Desktop Entry]
Name=Ulauncher
Comment=Application launcher
TryExec=/usr/bin/ulauncher
Exec=env GDK_BACKEND=wayland /usr/bin/ulauncher --hide-window
Icon=ulauncher
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
EOF
```

## 2. GNOME Shell extensions

Disable the Ubuntu features replaced by this setup. Keep AppIndicator enabled;
unlike Omakub, this setup uses it for application tray icons.

```bash
disable_if_installed() {
  gnome-extensions info "$1" >/dev/null 2>&1 &&
    gnome-extensions disable "$1" || true
}

disable_if_installed tiling-assistant@ubuntu.com
disable_if_installed ubuntu-dock@ubuntu.com
disable_if_installed ding@rastersoft.com

for uuid in \
  ubuntu-appindicators@ubuntu.com \
  appindicatorsupport@rgcjonas.gmail.com
do
  gnome-extensions info "$uuid" >/dev/null 2>&1 &&
    gnome-extensions enable "$uuid" || true
done
```

Install the selected extensions through GNOME Extension Manager, which chooses
a release compatible with the installed GNOME Shell version. They are optional:
the automated config reports missing UUIDs and configures each extension once
its schema is available.

```bash
extensions=(
  tactile@lundal.io
  just-perfection-desktop@just-perfection
  blur-my-shell@aunetx
  space-bar@luchrioh
  undecorate@sun.wxg@gmail.com
  tophat@fflewddur.github.io
  AlphabeticalAppGrid@stuarthayhurst
)
```

Copy the extension schemas system-wide so `gsettings` can configure them before
the next login, then compile the schema cache:

```bash
extension_root="$HOME/.local/share/gnome-shell/extensions"

for uuid in \
  tactile@lundal.io \
  just-perfection-desktop@just-perfection \
  blur-my-shell@aunetx \
  space-bar@luchrioh \
  tophat@fflewddur.github.io \
  AlphabeticalAppGrid@stuarthayhurst
do
  schema_dir="$extension_root/$uuid/schemas"
  [ -d "$schema_dir" ] || continue
  while IFS= read -r -d '' schema; do
    sudo install -m 0644 "$schema" /usr/share/glib-2.0/schemas/
  done < <(find "$schema_dir" -maxdepth 1 -name '*.gschema.xml' -print0)
done

sudo glib-compile-schemas /usr/share/glib-2.0/schemas
```

Apply the extension settings:

```bash
# Tactile: 25% / 50% / 25% columns, two rows, and generous gaps.
gsettings set org.gnome.shell.extensions.tactile col-0 1
gsettings set org.gnome.shell.extensions.tactile col-1 2
gsettings set org.gnome.shell.extensions.tactile col-2 1
gsettings set org.gnome.shell.extensions.tactile col-3 0
gsettings set org.gnome.shell.extensions.tactile row-0 1
gsettings set org.gnome.shell.extensions.tactile row-1 1
gsettings set org.gnome.shell.extensions.tactile gap-size 32

# Just Perfection.
gsettings set org.gnome.shell.extensions.just-perfection animation 2
gsettings set org.gnome.shell.extensions.just-perfection dash-app-running true
gsettings set org.gnome.shell.extensions.just-perfection workspace true
gsettings set org.gnome.shell.extensions.just-perfection workspace-popup false

# Blur My Shell: blur the overview, but not ordinary shell surfaces.
gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder blur false
gsettings set org.gnome.shell.extensions.blur-my-shell.lockscreen blur false
gsettings set org.gnome.shell.extensions.blur-my-shell.screenshot blur false
gsettings set org.gnome.shell.extensions.blur-my-shell.window-list blur false
gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur false
gsettings set org.gnome.shell.extensions.blur-my-shell.overview blur true
gsettings set org.gnome.shell.extensions.blur-my-shell.overview pipeline pipeline_default

# These are retained in case Ubuntu Dock/Dash-to-Dock is enabled later.
gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur true
gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock brightness 0.6
gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock sigma 30
gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock static-blur true
gsettings set org.gnome.shell.extensions.blur-my-shell.dash-to-dock style-dash-to-dock 0

# Space Bar.
gsettings set org.gnome.shell.extensions.space-bar.behavior smart-workspace-names false
gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-activate-workspace-shortcuts false
gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-move-to-workspace-shortcuts true
gsettings set org.gnome.shell.extensions.space-bar.shortcuts open-menu '@as []'

# TopHat: keep the compact network display and use bits for traffic rates.
gsettings set org.gnome.shell.extensions.tophat show-icons false
gsettings set org.gnome.shell.extensions.tophat show-cpu false
gsettings set org.gnome.shell.extensions.tophat show-disk false
gsettings set org.gnome.shell.extensions.tophat show-mem false
gsettings set org.gnome.shell.extensions.tophat show-fs false
gsettings set org.gnome.shell.extensions.tophat network-usage-unit bits

# Put application folders after individual applications.
gsettings set org.gnome.shell.extensions.alphabetical-app-grid folder-order-position end
```

Undecorate is intentionally left at its defaults.

Try to enable the newly installed extensions now. On Wayland, newly installed
extensions may not become visible to the running shell until the next login; in
that case repeat this loop after logging back in.

```bash
for uuid in "${extensions[@]}"; do
  gnome-extensions enable "$uuid" || true
done
```

## 3. Tokyo Night GNOME theme

This uses Ubuntu's Yaru assets instead of installing an additional GTK theme:

- color scheme: dark
- GTK theme: `Yaru-purple-dark`
- icon theme: `Yaru-purple`
- cursor theme: `Yaru`
- accent: purple, when supported by the installed GNOME version
- TopHat foreground: `#924d8b`

Install the Tokyo Night wallpaper from the pinned Omakub revision and apply the
theme:

```bash
background_dir="$HOME/.local/share/backgrounds"
background="$background_dir/tokyo-night.jpg"
mkdir -p "$background_dir"

curl -fL \
  https://raw.githubusercontent.com/basecamp/omakub/c873902/themes/tokyo-night/background.jpg \
  -o "$background"

gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface cursor-theme Yaru
gsettings set org.gnome.desktop.interface gtk-theme Yaru-purple-dark
gsettings set org.gnome.desktop.interface icon-theme Yaru-purple

if gsettings list-keys org.gnome.desktop.interface | grep -qx accent-color; then
  gsettings set org.gnome.desktop.interface accent-color purple
fi

background_uri="file://$(realpath "$background")"
gsettings set org.gnome.desktop.background picture-uri "$background_uri"
gsettings set org.gnome.desktop.background picture-uri-dark "$background_uri"
gsettings set org.gnome.desktop.background picture-options zoom

gsettings set org.gnome.shell.extensions.tophat meter-fg-color '#924d8b'
```

## 4. Keyboard shortcuts

Use six fixed workspaces, `Alt+number` for favourites, and `Super+number` for
workspaces:

```bash
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6

gsettings set org.gnome.desktop.wm.keybindings close "['<Super>w']"
gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings begin-resize "['<Super>BackSpace']"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Shift>F11']"
gsettings set org.gnome.settings-daemon.plugins.media-keys next "['<Shift>AudioPlay']"

# Do not let Dash-to-Dock consume Super/number shortcuts if it is later enabled.
gsettings set org.gnome.shell.extensions.dash-to-dock hot-keys false

for number in {1..9}; do
  gsettings set org.gnome.shell.keybindings "switch-to-application-$number" \
    "['<Alt>$number']"
done

for number in {1..6}; do
  gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$number" \
    "['<Super>$number']"
done
```

Create four custom bindings:

| Shortcut | Command |
|---|---|
| `Super+Space` | Toggle Ulauncher, or start it when it is not running |
| `Ctrl+Print` | Open the Flameshot capture UI |
| `Shift+Alt+2` | Open a new Alacritty window |
| `Shift+Alt+1` | Open a new Brave Origin window |

```bash
binding_root=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['$binding_root/custom0/', '$binding_root/custom1/', '$binding_root/custom2/', '$binding_root/custom3/']"

# Free Super+Space from GNOME's input-source switcher.
gsettings set org.gnome.desktop.wm.keybindings switch-input-source '@as []'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" \
  name Ulauncher
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" \
  command 'sh -c "pgrep -x ulauncher && { ulauncher-toggle || true; } || setsid -f ulauncher"'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom0/" \
  binding '<Super>space'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" \
  name Flameshot
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" \
  command 'sh -c -- "flameshot gui"'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom1/" \
  binding '<Control>Print'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" \
  name 'New Alacritty Window'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" \
  command alacritty
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom2/" \
  binding '<Shift><Alt>2'

brave_command="$(command -v brave-origin 2>/dev/null || command -v brave-browser 2>/dev/null || true)"
[ -n "$brave_command" ] || brave_command=brave-origin
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" \
  name 'New Brave Window'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" \
  command "$brave_command --new-window"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$binding_root/custom3/" \
  binding '<Shift><Alt>1'
```

Do not add Omakub's ASDControl shortcuts by default. They are specific to Apple
Studio/XDR displays and invoke a command that `linux-setup` does not install.

## 5. General GNOME settings

Apply the personal defaults:

```bash
# Window placement and workspaces.
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6

# Interface and calendar.
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
gsettings set org.gnome.desktop.calendar show-weekdate true

# Do not let an unreliable ambient sensor control display brightness.
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false

# Normal lock and idle behaviour after setup finishes.
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.session idle-delay 0

# Caps Lock becomes the Compose key.
gsettings set org.gnome.desktop.input-sources xkb-options "['compose:caps']"
```

The Framework-specific `0.8` text scaling and 16px cursor from Omakub should
only be applied when both of these are true:

- DMI manufacturer is `Framework`.
- Active display resolution is `2256x1504`.

Otherwise leave GNOME's scaling and cursor size unchanged. If the conditions
match, run:

```bash
gsettings set org.gnome.desktop.interface text-scaling-factor 0.8
gsettings set org.gnome.desktop.interface cursor-size 16
```

## 6. Overview favourites and app grid

Ubuntu Dock is disabled, so `org.gnome.shell favorite-apps` controls the dash in
the GNOME overview. If an always-visible dock is wanted later, enable Ubuntu
Dock; the same favourites list will be reused.

Desktop entry names vary slightly between Ubuntu/Debian releases and package
sources. Resolve the first installed entry for each application instead of
writing IDs that may not exist:

```bash
desktop_dirs=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  /usr/local/share/applications
  /usr/share/applications
  /var/lib/flatpak/exports/share/applications
)

desktop_exists() {
  local id="$1" dir
  for dir in "${desktop_dirs[@]}"; do
    [ -f "$dir/$id" ] && return 0
  done
  return 1
}

first_desktop() {
  local id
  for id in "$@"; do
    if desktop_exists "$id"; then
      printf '%s\n' "$id"
      return 0
    fi
  done
  return 1
}

add_favourite() {
  local id
  id="$(first_desktop "$@" || true)"
  [ -n "$id" ] && favourites+=("$id")
}

favourites=()
add_favourite brave-origin.desktop com.brave.Origin.desktop brave-browser.desktop
add_favourite Alacritty.desktop org.alacritty.Alacritty.desktop
add_favourite code.desktop
add_favourite thunderbird.desktop org.mozilla.Thunderbird.desktop
add_favourite signal-desktop.desktop org.signal.Signal.desktop
add_favourite spotify.desktop com.spotify.Client.desktop
add_favourite org.keepassxc.KeePassXC.desktop keepassxc.desktop
add_favourite org.gnome.Nautilus.desktop nautilus.desktop
add_favourite org.gnome.Settings.desktop gnome-control-center.desktop

if [ "${#favourites[@]}" -gt 0 ]; then
  printf -v favourite_values "'%s', " "${favourites[@]}"
  gsettings set org.gnome.shell favorite-apps "[${favourite_values%, }]"
fi
```

This makes the dock order:

1. Brave Origin
2. Alacritty
3. VS Code
4. Thunderbird
5. Signal
6. Spotify
7. KeePassXC
8. Files
9. Settings

Missing apps are skipped without leaving broken favourites.

Create grid folders for the applications installed by `linux-setup`:

```bash
ALACRITTY_ID="$(first_desktop Alacritty.desktop org.alacritty.Alacritty.desktop || true)"
VSCODE_ID="$(first_desktop code.desktop || true)"
THUNDERBIRD_ID="$(first_desktop thunderbird.desktop org.mozilla.Thunderbird.desktop || true)"
SIGNAL_ID="$(first_desktop signal-desktop.desktop org.signal.Signal.desktop || true)"
SPOTIFY_ID="$(first_desktop spotify.desktop com.spotify.Client.desktop || true)"
VLC_ID="$(first_desktop vlc.desktop org.videolan.VLC.desktop || true)"

variant_list() {
  local result='' id
  for id in "$@"; do
    [ -n "$id" ] && result+="'$id', "
  done
  printf '[%s]\n' "${result%, }"
}

gsettings set org.gnome.desktop.app-folders folder-children \
  "['Utilities', 'Sundry', 'YaST', 'Development', 'Communication', 'Media']"

gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ \
  name 'Development'
gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ \
  apps "$(variant_list "$ALACRITTY_ID" "$VSCODE_ID")"

gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Communication/ \
  name 'Communication'
gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Communication/ \
  apps "$(variant_list "$THUNDERBIRD_ID" "$SIGNAL_ID")"

gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Media/ \
  name 'Media'
gsettings set \
  org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Media/ \
  apps "$(variant_list "$SPOTIFY_ID" "$VLC_ID")"
```

Brave, KeePassXC, Files, and Settings remain top-level grid entries. Do not
remove System Monitor, btop, Flameshot, Vim, ImageMagick, or other packaged
desktop entries: this setup does not install Omakub's replacement launchers.

## 7. Finish and verify

Log out and back in, or reboot, so GNOME Shell loads the user extensions and
updated schemas. Then enable the extensions once more if the pre-logout enable
attempt could not see them:

```bash
for uuid in \
  tactile@lundal.io \
  just-perfection-desktop@just-perfection \
  blur-my-shell@aunetx \
  space-bar@luchrioh \
  undecorate@sun.wxg@gmail.com \
  tophat@fflewddur.github.io \
  AlphabeticalAppGrid@stuarthayhurst
do
  gnome-extensions enable "$uuid" || true
done
```

Verify the effective state:

```bash
gnome-extensions list --enabled
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface icon-theme
gsettings get org.gnome.desktop.interface monospace-font-name
gsettings get org.gnome.mutter dynamic-workspaces
gsettings get org.gnome.desktop.wm.preferences num-workspaces
gsettings get org.gnome.shell favorite-apps
gsettings get org.gnome.desktop.app-folders folder-children
```

Expected highlights are `Yaru-purple-dark`, `Yaru-purple`, JetBrainsMono,
`dynamic-workspaces=false`, and six workspaces. Finally test `Super+Space`,
`Ctrl+Print`, `Shift+Alt+1`, `Shift+Alt+2`, `Alt+1`, and `Super+1` interactively.
