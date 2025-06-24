#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# Check if sensor is already installed
if is_sensor_installed; then
    log "INFO" "[INSTALL] Falcon Sensor is already installed. Skipping installation."
    set_status "Install" "Installing the Falcon Sensor" "success" "The Falcon Sensor is already installed" "Falcon Sensor" "success" "The Falcon Sensor is already installed"
    exit 0
fi

log "INFO" "[INSTALL] Starting Falcon Sensor installation"

run_falcon_installer "install"
exit $?