#!/usr/bin/bash
set -euo pipefail

readonly VERSION="0.0.0"
readonly HANDLER_DIR="${script_path:?script_path must be set before sourcing helper.sh}"
readonly MAX_LOG_SIZE=5242880  # 5 MB

# Check if running in an Azure Arc environment
is_arc_environment() {
    if [ -f "/opt/azcmagent/bin/himds" ]; then
        return 0
    fi
    return 1
}

# Get the log folder path from HandlerEnvironment.json
get_logs_folder() {
    LOGS_FOLDER=$(cat "$HANDLER_DIR/HandlerEnvironment.json" | grep -o '"logFolder":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
}

rotate_log() {
    local log_file="$LOGS_FOLDER/cshandler.log"
    if [ -f "$log_file" ]; then
        local size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
        if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
            mv -f "$log_file" "${log_file}.1"
        fi
    fi
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date --utc --iso-8601=seconds)

    get_logs_folder
    rotate_log

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
    local cfg_path=$(cat "$HANDLER_DIR/HandlerEnvironment.json" | grep -o '"configFolder":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    local config_files_path="$cfg_path/*.settings"
    CONFIG_FILE=$(ls $config_files_path 2>/dev/null | sort -V | tail -1)
}

# Get the status folder path from HandlerEnvironment.json
get_status_folder() {
    STATUS_FOLDER=$(cat "$HANDLER_DIR/HandlerEnvironment.json" | grep -o '"statusFolder":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
}

# Extract host and port from a proxy URL, stripping scheme and credentials
# e.g. http://user:password@proxy:8080 -> proxy:8080
parse_proxy_url() {
    local url="$1"
    local stripped="$url"

    stripped="${stripped#http://}"
    stripped="${stripped#https://}"

    if [[ "$stripped" == *"@"* ]]; then
        stripped="${stripped#*@}"
    fi

    stripped="${stripped%%/*}"

    echo "$stripped"
}

# Resolve proxy configuration from the Arc agent
get_arc_proxy_config() {
    if [ -n "${ProxySettings:-}" ]; then
        HTTPS_PROXY=$(parse_proxy_url "$ProxySettings")
        log "INFO" "Using Arc proxy from ProxySettings environment variable: $HTTPS_PROXY"
        return
    fi

    local arc_config="/var/opt/azcmagent/localconfig.json"
    if [ -f "$arc_config" ]; then
        local proxy_url
        proxy_url=$(grep -o '"proxy.url": *"[^"]*"' "$arc_config" | cut -d'"' -f4 || true)
        if [ -n "$proxy_url" ]; then
            HTTPS_PROXY=$(parse_proxy_url "$proxy_url")
            log "INFO" "Using Arc proxy from localconfig.json: $HTTPS_PROXY"
            return
        fi
    fi
}

# Parse proxy configuration from config file
get_proxy_config() {
    PROXY_HOST=""
    PROXY_PORT=""
    HTTPS_PROXY=""

    # On Arc, inherit the agent's proxy settings first
    if is_arc_environment; then
        get_arc_proxy_config
        if [ -n "$HTTPS_PROXY" ]; then
            return
        fi
    fi

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

    # Get sequence number from environment variable, fallback to 0 if not available
    local statusNum="${ConfigSequenceNumber:-0}"
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

    # Azure Arc only supports system-assigned managed identities. If a user-assigned
    # managed identity client ID is configured, warn and clear it so the installer
    # falls back to system-assigned identity via HIMDS challenge/response.
    if is_arc_environment && [ -f "$CONFIG_FILE" ]; then
        local mi_client_id
        mi_client_id=$(grep -o '"azure_managed_identity_client_id": *"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 | head -1 || true)
        if [ -n "$mi_client_id" ]; then
            log "WARN" "[$operation_upper] Azure Arc does not support user-assigned managed identities."
        fi
    fi

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
