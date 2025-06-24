#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

get_logs_folder

# Check if sensor is already installed
if ! is_sensor_installed; then
    log "INFO" "[UNINSTALL] Falcon Sensor is already been uninstalled. Skipping uninstall process."
    set_status "Uninstall" "Uninstalling the Falcon Sensor" "success" "The Falcon Sensor is not installed" "Falcon Sensor" "success" "The Falcon Sensor is not installed"
    exit 0
fi

log "INFO" "[UNINSTALL] Starting Falcon Sensor removal process"

run_falcon_installer "uninstall" "$LOGS_FOLDER/falcon"
exit $?
