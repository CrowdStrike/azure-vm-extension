#!/usr/bin/bash

set -euo pipefail

readonly script_path=$(dirname $(readlink -f "$0"))
source $script_path/helper.sh

# Detect if this is a Debian-based system and update package cache
if [ -f /etc/debian_version ] || grep -qi debian /etc/os-release 2>/dev/null; then
    log "INFO" "[INSTALL] Detected Debian-based system, updating package cache"
    if ! apt update; then
        log "WARN" "[INSTALL] Failed to update apt package cache, continuing anyway"
    else
        log "INFO" "[INSTALL] Successfully updated apt package cache"
    fi
fi

log "INFO" "[INSTALL] Falcon Sensor installation will happen on enable"

exit 0
