#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

get_logs_folder

if is_sensor_installed; then
    log "ERROR" "[UNINSTALL] Falcon Sensor is still installed after uninstall process was completed in the disable step. Please check the logs for more details. Please see '$LOGS_FOLDER/falcon/falcon-installer.log' for more info."
    exit 1
fi

exit 0