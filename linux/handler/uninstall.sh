#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

log "INFO" "[UNINSTALL] Falcon Sensor uninstall should have already happened during disable"

exit 0
