#!/usr/bin/bash
set -euo pipefail

readonly SERVICE_NAME="falcon-sensor.service"
readonly VERSION="0.0.0"

# Get the log folder path from HandlerEnvironment.json
get_logs_folder() {
    LOGS_FOLDER=$(cat HandlerEnvironment.json | grep -o '"logFolder": "[^"]*"' | cut -d'"' -f4)
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date --utc --iso-8601=seconds)

    get_logs_folder

    echo "[$timestamp] $level $message"
    echo "[$timestamp] $level $message" >> "$LOGS_FOLDER/cshandler.log"
}

# Detect system architecture
detect_architecture() {
    ARCH=$(uname -m)

    if [ "$ARCH" = "aarch64" ]; then
        ARCH_SUFFIX="arm64"
    elif [ "$ARCH" = "x86_64" ]; then
        ARCH_SUFFIX="x86_64"
    else
        log "ERROR" "Unsupported architecture: $ARCH"
        exit 1
    fi

    INSTALLER="falcon-installer-${ARCH_SUFFIX}"
    log "INFO" "Detected architecture: $ARCH, using installer: $INSTALLER"
}

# Check if sensor is already installed
is_sensor_installed() {
    if [ -f "/opt/CrowdStrike/falconctl" ]; then
        return 0  # true, sensor is installed
    else
        return 1  # false, sensor is not installed
    fi
}

# Get the configuration file path from HandlerEnvironment.json
get_config_file() {
    local cfg_path=$(cat HandlerEnvironment.json | grep -o '"configFolder": "[^"]*"' | cut -d'"' -f4)
    local config_files_path="$cfg_path/*.settings"
    CONFIG_FILE=$(ls $config_files_path 2>/dev/null | sort -V | tail -1)
}

# Get the status folder path from HandlerEnvironment.json
get_status_folder() {
    STATUS_FOLDER=$(cat HandlerEnvironment.json | grep -o '"statusFolder": "[^"]*"' | cut -d'"' -f4)
}

# Parse proxy configuration from config file
get_proxy_config() {
    PROXY_HOST=""
    PROXY_PORT=""
    HTTPS_PROXY=""

    if [ -f "$CONFIG_FILE" ]; then
        # Extract proxy_host and proxy_port from settings
        PROXY_HOST=$(cat "$CONFIG_FILE" | grep -o '"proxy_host": *"[^"]*"' | cut -d'"' -f4 | head -1 || true)
        PROXY_PORT=$(cat "$CONFIG_FILE" | grep -o '"proxy_port": *"[^"]*"' | cut -d'"' -f4 | head -1 || true)

        # Construct HTTPS_PROXY - proxy_host is required, proxy_port is optional
        if [ ! -z "$PROXY_HOST" ]; then
            if [ ! -z "$PROXY_PORT" ]; then
                HTTPS_PROXY="$PROXY_HOST:$PROXY_PORT"
            else
                HTTPS_PROXY="$PROXY_HOST"
            fi
            log "INFO" "Proxy configuration found: $HTTPS_PROXY"
        fi
    fi
}

# Set the status of the VM Extension
set_status() {
    local name="${1}"
    local operation="${2}"
    local status="${3}"
    local message="${4}"
    local subName="${5}"
    local subStatus="${6}"
    local subMessage="${7}"
    local timestamp=$(date --utc --iso-8601=seconds)
    local statusNum="0"
    local code=0

    # Get the status folder path
    get_status_folder

    local status_file="$STATUS_FOLDER/$statusNum.status"
    if [ "$subStatus" = "error" ]; then
        code=1
    fi

    json="[
  {
    \"version\": \"1.0\",
    \"timestampUTC\": \"$timestamp\",
    \"status\": {
      \"name\": \"$name\",
      \"operation\": \"$operation\",
      \"status\": \"$status\",
      \"code\": $code,
      \"formattedMessage\": {
        \"lang\": \"en-US\",
        \"message\": \"$message\"
      },
      \"substatus\": [
        {
          \"name\": \"$subName\",
          \"status\": \"$subStatus\",
          \"code\": $code,
          \"formattedMessage\": {
            \"lang\": \"en-US\",
            \"message\": \"$subMessage\"
          }
        }
      ]
    }
  }
]"
    echo $json > "$status_file"
}

# handle the installation or uninstall of the Falcon Sensor
run_falcon_installer() {
    local operation="$1"
    local operation_upper="${operation^^}"  # Convert to uppercase
    local logs_dir="${2:-$script_path/falcon}"  # Default to $script_path/falcon if not provided

    # Detect architecture and set installer
    detect_architecture

    # Get Config file
    get_config_file

    # Get proxy configuration
    get_proxy_config

    if [ ! -d "$logs_dir" ]; then
        mkdir -p "$logs_dir"
    fi

    # Run the installer with appropriate parameters
    if [ "$operation" = "uninstall" ]; then
        log "INFO" "[$operation_upper] running the Falcon installer to remove the Falcon sensor..."
        if [ ! -z "$HTTPS_PROXY" ]; then
            log "INFO" "[$operation_upper] Using proxy configuration: $HTTPS_PROXY"
            { installer_output=$(sudo HTTPS_PROXY="$HTTPS_PROXY" "$script_path/$INSTALLER" --uninstall --verbose --enable-file-logging --user-agent="azure-vm-extension/$VERSION" --tmpdir "$logs_dir" --config "$CONFIG_FILE" 2>"$logs_dir/falcon-installer.log"); installer_exit_code=$?; } || true
        else
            { installer_output=$(sudo "$script_path/$INSTALLER" --uninstall --verbose --enable-file-logging --user-agent="azure-vm-extension/$VERSION" --tmpdir "$logs_dir" --config "$CONFIG_FILE" 2>"$logs_dir/falcon-installer.log"); installer_exit_code=$?; } || true
        fi
    else
        log "INFO" "[$operation_upper] running the Falcon installer..."
        if [ ! -z "$HTTPS_PROXY" ]; then
            log "INFO" "[$operation_upper] Using proxy configuration: $HTTPS_PROXY"
            { installer_output=$(sudo HTTPS_PROXY="$HTTPS_PROXY" "$script_path/$INSTALLER" --verbose --enable-file-logging --user-agent="azure-vm-extension/$VERSION" --tmpdir "$logs_dir" --config "$CONFIG_FILE" 2>"$logs_dir/falcon-installer.log"); installer_exit_code=$?; } || true
        else
            { installer_output=$(sudo "$script_path/$INSTALLER" --verbose --enable-file-logging --user-agent="azure-vm-extension/$VERSION" --tmpdir "$logs_dir" --config "$CONFIG_FILE" 2>"$logs_dir/falcon-installer.log"); installer_exit_code=$?; } || true
        fi
    fi

    if [ $installer_exit_code -eq 0 ]; then
        # Set success message based on operation
        local success_message="Falcon Sensor $([ "$operation" = "uninstall" ] && echo "uninstall" || echo "installation") process completed"
        local operation_capitalized="$(tr '[:lower:]' '[:upper:]' <<< ${operation:0:1})${operation:1}"
        local operation_gerund="$([ "$operation" = "uninstall" ] && echo "Uninstalling" || echo "Installing")"

        log "INFO" "[$operation_upper] $success_message"

        set_status "$operation_capitalized" "$operation_gerund the Falcon Sensor" "success" \
                  "The $success_message" "Falcon Sensor" "success" "The $success_message"
        return 0
    else
        # Set error message based on operation
        local error_message="The Falcon Sensor $([ "$operation" = "uninstall" ] && echo "uninstall" || echo "install") failed to complete."
        local operation_capitalized="$(tr '[:lower:]' '[:upper:]' <<< ${operation:0:1})${operation:1}"
        local operation_gerund="$([ "$operation" = "uninstall" ] && echo "Uninstalling" || echo "Installing")"

        log "ERROR" "[$operation_upper] $error_message Please see '$logs_dir/falcon-installer.log' for more info."

        set_status "$operation_capitalized" "$operation_gerund the Falcon Sensor" "failed" \
                  "$error_message" "Falcon Sensor" "error" \
                  "$error_message Please see '$logs_dir/falcon-installer.log' for more info."
        return 1
    fi
}
