#!/bin/bash

node_apps=(
	pnpm
	@openai/codex
	@google/gemini-cli
)

if command -v npm >/dev/null 2>&1; then
	for app in "${node_apps[@]}"; do
		run_quiet "Installing $app" npm i -g "$app"
	done
elif command -v mise >/dev/null 2>&1; then
	for app in "${node_apps[@]}"; do
		run_quiet "Installing $app" mise exec node@lts -- npm i -g "$app"
	done
else
	log_warn "npm is not available; skipping global node app installation."
fi
