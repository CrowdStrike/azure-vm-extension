#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

log "INFO" "[INSTALL] Falcon Sensor installation will happen on enable"

exit 0
