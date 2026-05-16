#!/bin/bash

for installer in "$LINUX_SETUP_INSTALL_DIR/install/terminal"/*.sh; do
  log_step "terminal/$(basename "$installer" .sh)"
  source "$installer"
done

log_step "node apps"
source "$LINUX_SETUP_INSTALL_DIR/install/node-apps.sh"
