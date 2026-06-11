#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

log "INFO" "[RESET] Resetting extension handler state"

get_status_folder

if [ -d "$STATUS_FOLDER" ]; then
    rm -f "$STATUS_FOLDER"/*.status
    log "INFO" "[RESET] Cleared status files from $STATUS_FOLDER"
fi

log "INFO" "[RESET] Extension handler state has been reset"

exit 0
