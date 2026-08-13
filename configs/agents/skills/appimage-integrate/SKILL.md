---
name: appimage-integrate
description: Manually integrate a supplied AppImage into the user's desktop and shell using the configured local desktop-entry template.
disable-model-invocation: true
argument-hint: <path-to-AppImage> [command-name]
---

# AppImage integration

Use this workflow only when the user explicitly invokes this skill.

## Local configuration

Edit this value before first use:

```text
DESKTOP_TEMPLATE_PATH=$HOME/dev/linux-setup/configs/agents/skills/appimage-integrate/assets/TEMPLATE.desktop
```

Defaults:

```text
APPIMAGE_DIR=$HOME/Applications
DESKTOP_DIR=$HOME/.local/share/applications
ICON_DIR=$HOME/Applications/icons
BIN_DIR=$HOME/.local/bin
```

The executable/AppImage path comes from the skill invocation or the user's same-turn request. An optional second argument may specify the shell command name. If no command name is supplied, derive a short lowercase command name from the application's bundled metadata.

## Goal

Given an AppImage, create and verify all of the following:

1. A stable, real AppImage file at a version-independent path.
2. A desktop entry rendered from `DESKTOP_TEMPLATE_PATH`.
3. A persistent icon copied out of the AppImage.
4. A detached command-line launcher in `$HOME/.local/bin`.
5. No extraction directory or other scratch files left behind.

Do not use a symlink as the installed AppImage path. Built-in AppImage updaters may replace or resolve symlinks differently. The desktop entry and CLI launcher must both ultimately target a stable regular file.

## Procedure

### 1. Validate and establish the stable AppImage path

- Resolve the input to an absolute path.
- Verify it exists and is executable. If the AppImage is not executable, run `chmod +x` on it.
- Verify it behaves as an AppImage by successfully supporting `--appimage-extract` in the extraction step below.
- The final installed AppImage should be a regular file under `$APPIMAGE_DIR` with a version-independent, architecture-independent name such as `Foo.AppImage`, not `Foo-1.2.3-x86_64.AppImage`.
- If the supplied AppImage is already a regular file at a suitable stable path, keep it in place.
- Otherwise copy it to `$APPIMAGE_DIR` under a version-independent name and make it executable. Do not leave the desktop entry pointing at a temporary/download/versioned pathname.

Do not overwrite an unrelated existing AppImage. If the target already exists, report back to the user.

### 2. Extract into a temporary directory and guarantee cleanup

Use `mktemp -d` and install a cleanup trap before extracting. Never extract into the current working directory.

Equivalent shell pattern:

```bash
tmpdir="$(mktemp -d)"
trap 'rm -rf -- "$tmpdir"' EXIT INT TERM HUP
(
  cd "$tmpdir"
  "$appimage" --appimage-extract >/dev/null
)
appdir="$tmpdir/squashfs-root"
```

The cleanup trap must remain active until every needed metadata/icon file has been copied somewhere persistent. Before finishing, explicitly verify that the extraction directory is gone.

### 3. Inspect bundled desktop metadata

Prefer the single top-level `*.desktop` entry in the extracted AppDir. If it is a symlink, follow it. Only fall back to `usr/share/applications/*.desktop` when the top-level entry is missing or unusable.

Read at least:

- desktop filename/basename
- `Name`
- `Comment`
- `Exec`
- `Icon`
- `Categories`
- `Keywords`
- `MimeType`
- `Terminal`
- `StartupNotify`
- `StartupWMClass`

Use the bundled entry as metadata/reference, not as the final file. The user's configured template is authoritative for final structure and comments.

Preserve meaningful `Exec` field codes such as `%u`, `%U`, `%f`, or `%F` from the bundled entry, but replace its executable token with the absolute stable AppImage path. Do not copy a bundled relative executable name into the installed desktop entry.

For desktop/window identity:

- Prefer the basename of the bundled desktop file as the installed desktop ID/filename unless there is stronger application-provided evidence for another ID.
- Preserve `StartupWMClass` when the bundled desktop entry provides it.
- Do not invent a reverse-DNS application ID merely for aesthetics.
- If GNOME window grouping/icon matching is later wrong, diagnose the actual native Wayland `app_id` or X11/XWayland `WM_CLASS` and correct the desktop filename/`StartupWMClass` accordingly.

### 4. Find and install the icon

Use the bundled desktop entry's `Icon=` value as the primary lookup key.

Search in this order:

1. A matching top-level icon in the AppDir.
2. The target of top-level `.DirIcon`.
3. Matching icons below `usr/share/icons`, especially `hicolor/.../apps/`.
4. `usr/share/pixmaps` as a fallback.

When multiple candidates exist:

- prefer SVG/scalable artwork;
- otherwise prefer the largest sensible PNG;
- avoid tiny tray/status icons when an application icon is available.

Copy the selected file to the user's configured `$ICON_DIR` under a version-independent name such as `Foo.svg` or the same path with `.png`.

Use the resulting absolute path in the final desktop entry's `Icon=` field. This intentionally avoids depending on icon-theme cache refreshes.

### 5. Render the user's desktop template

Read `DESKTOP_TEMPLATE_PATH` (defaults to the bundled `assets/TEMPLATE.desktop` in this skill). If it still contains a placeholder or points at a non-existent file, stop and tell the user to configure it.

Copy the template to:

```text
$HOME/.local/share/applications/<desktop-id>.desktop
```

Then edit only the application-specific values required by the template. Preserve the template's comments, ordering, and conventions.

At minimum ensure:

```ini
Type=Application
Name=<bundled application name>
Exec=<absolute stable AppImage path> <preserved applicable field codes/arguments>
Icon=<absolute persistent extracted icon path>
Terminal=false
```

Also populate `Comment`, `Categories`, `Keywords`, `MimeType`, `StartupNotify`, and `StartupWMClass` when the template contains those fields and bundled metadata provides useful values.

Set the file mode to `0644`.

If `desktop-file-validate` exists, run it and fix validation errors. If `update-desktop-database` exists, refresh `$HOME/.local/share/applications` after installing the entry.

### 6. Install a command-line launcher

The correct user executable directory is `$HOME/.local/bin`.

Create:

```text
$HOME/.local/bin/<command-name>
```

from `assets/detached-appimage-launcher.sh` in this skill. Substitute:

- `__COMMAND_NAME__` with the chosen command name.
- `__APPIMAGE_PATH__` with the absolute stable AppImage path.

Set the launcher mode to `0755`.

The launcher must return control to the invoking shell immediately during normal GUI launches. Do not wrap the AppImage in an interactive/login shell and do not foreground it by default.

The template uses `setsid --fork` when available and falls back to `nohup ... &`. It also provides `APPIMAGE_LAUNCHER_FOREGROUND=1` for debugging or callers that intentionally want synchronous execution.

The launcher unsets inherited AppImage/Electron runtime variables before starting the new AppImage. Note that the AppImage runtime may set its own `APPIMAGE`, `APPDIR`, and related variables again inside the GUI application's process tree. If an embedded terminal inside that GUI inherits those runtime variables, handle that separately in shell startup or application-specific configuration; the outer launcher cannot remove variables that the AppImage runtime creates after launch.

Check whether `$HOME/.local/bin` is present in `PATH`. If not, report that fact; do not silently edit shell startup files unless the user explicitly asked for it.

### 7. Verify

Before reporting success, verify all of these:

- installed AppImage is a regular executable file;
- desktop entry exists and points to that exact stable path;
- icon exists outside the extracted AppDir;
- CLI launcher exists, is executable, and targets the same stable path;
- CLI launcher returns promptly for a normal launch;
- desktop file validates when `desktop-file-validate` is available;
- temporary extraction directory has been removed.

## Shell environment contamination check

After creating the launcher, inspect the very beginning of `~/.zshrc` for an AppImage environment cleanup guard similar to:

```bash
if [[ -n "${APPIMAGE:-}" && "$APPIMAGE" == *APP_NAME_OR_PATTERN* ]]; then
	unset APPIMAGE APPDIR ARGV0 ELECTRON_RUN_AS_NODE
fi
```

This workaround is only needed for applications that propagate AppImage runtime environment variables into shells they launch. Do not modify ~/.zshrc automatically.

If the current application appears likely to require this workaround and no matching guard exists near the top of ~/.zshrc, include a visible hint in the final output telling the user to add one. If a suitable guard already exists, do not mention it.

## Output format

If everything succeeds and no hint is required, output exactly one sentence:

Installed <APP_NAME> with desktop launcher <DESKTOP_FILE> and command <COMMAND_NAME>.

If a shell-environment hint is required, output exactly two lines:

Installed <APP_NAME> with desktop launcher <DESKTOP_FILE> and command <COMMAND_NAME>.
HINT: <APP_NAME> may require an APPIMAGE/APPDIR cleanup guard near the top of ~/.zshrc for shells launched from the application.

Do not include explanations, step summaries, extracted metadata, paths other than those required above, or descriptions of what the agent did.
