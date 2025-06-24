#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# Check if sensor is already installed
if is_sensor_installed; then
    log "INFO" "[UPDATE] Skipping the update step as the sensor is already installed"
    set_status "Update" "Updating the Falcon Sensor" "success" "The Falcon Sensor is already installed" "Falcon Sensor" "success" "The Falcon Sensor is already installed"
    exit 0
fi

run_falcon_installer "update"
exit $?
