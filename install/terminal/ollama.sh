#!/bin/bash

if ! command -v ollama >/dev/null 2>&1; then
  run_quiet "Installing Ollama" bash -c 'curl -fsSL https://ollama.com/install.sh | sh'
else
  log_info "Ollama is already installed"
fi
