#!/bin/bash

run_quiet "Installing git" sudo apt-get install -y -qq git

# configure git settings
if [ -n "${CONFIG_FULL_NAME:-}" ]; then
	run_quiet "Setting git user.name" git config --global user.name "$CONFIG_FULL_NAME"
fi

if [ -n "${CONFIG_EMAIL:-}" ]; then
	run_quiet "Setting git user.email" git config --global user.email "$CONFIG_EMAIL"
fi
