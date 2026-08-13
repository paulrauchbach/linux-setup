#!/usr/bin/env bash
set -euo pipefail

command_name='__COMMAND_NAME__'
appimage='__APPIMAGE_PATH__'

if [[ ! -f "$appimage" || ! -x "$appimage" ]]; then
    printf '%s: AppImage not found or not executable: %s\n' "$command_name" "$appimage" >&2
    exit 1
fi

# Clean up AppImage/Electron state inherited when this command is launched
# from a terminal embedded in another AppImage application.
unset APPDIR APPIMAGE ARGV0 ELECTRON_RUN_AS_NODE

# Debug/synchronous escape hatch:
#   APPIMAGE_LAUNCHER_FOREGROUND=1 <command> [args...]
if [[ "${APPIMAGE_LAUNCHER_FOREGROUND:-0}" == '1' ]]; then
    exec "$appimage" "$@"
fi

# Normal GUI invocation: detach completely so the caller gets its shell back.
# setsid --fork starts the app in a new session and returns immediately.
if command -v setsid >/dev/null 2>&1; then
    setsid --fork "$appimage" "$@" </dev/null >/dev/null 2>&1
else
    # Portable fallback when util-linux setsid is unavailable.
    nohup "$appimage" "$@" </dev/null >/dev/null 2>&1 &
fi
