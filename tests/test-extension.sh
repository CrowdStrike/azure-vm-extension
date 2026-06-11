#!/bin/bash

# Crowdstrike VM Extension Multi-OS Testing Script
# This script deploys and tests the Crowdstrike Falcon extension across multiple operating systems

set -euo pipefail

# Default configuration
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${SUBSCRIPTION_ID:-}}"
LOCATION="centraluseuap"
TEMPLATE_FILE="./vm-test-template.json"
PARAMETERS_FILE="./vm-test-parameters.json"
CONFIG_FILE="./test.config"
VMSS_TEMPLATE_FILE="./vmss-test-template.json"
VMSS_PARAMETERS_FILE="./vmss-test-parameters.json"

# Extension settings
FALCON_CLIENT_ID="${FALCON_CLIENT_ID:-}"
FALCON_CLIENT_SECRET="${FALCON_CLIENT_SECRET:-}"
LINUX_ADMIN_PASSWORD="${LINUX_ADMIN_PASSWORD:-}"
WINDOWS_ADMIN_PASSWORD="${WINDOWS_ADMIN_PASSWORD:-}"
EXTENSION_PUBLISHER="Crowdstrike.Falcon"
EXTENSION_NAME="CrowdstrikeFalconSensor"
SENSOR_UPDATE_POLICY="${SENSOR_UPDATE_POLICY:-platform_default}"

# Test settings
OS_TYPE="both"
CLEANUP_AFTER_TEST="true"
WAIT_TIMEOUT=1200
DEPLOYMENT_TYPE="both"
AZURE_DEBUG="false"
ARC_MODE="false"

# Arc-specific settings
ARC_MACHINE_NAMES=()
ARC_RESOURCE_GROUP=""
ARC_SKIP_CLEANUP="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# OS configuration helper function (bash 3.2 compatible)
get_os_config() {
    local os_type=$1
    local config_key=$2

    case "$os_type:$config_key" in
        "Linux:admin_password") echo "$LINUX_ADMIN_PASSWORD" ;;
        "Linux:resource_group_prefix") echo "CS-Linux-Test" ;;
        "Linux:vm_name_prefix") echo "cstest" ;;
        "Windows:admin_password") echo "$WINDOWS_ADMIN_PASSWORD" ;;
        "Windows:resource_group_prefix") echo "CS-Windows-Test" ;;
        "Windows:vm_name_prefix") echo "cstest" ;;
        *) echo "" ;;
    esac
}

# Logging functions
log() {
    local level=$1
    shift
    local color=""
    local prefix=""

    case $level in
        "INFO") color="$BLUE"; prefix="[INFO]" ;;
        "SUCCESS") color="$GREEN"; prefix="[SUCCESS]" ;;
        "WARNING") color="$YELLOW"; prefix="[WARNING]" ;;
        "ERROR") color="$RED"; prefix="[ERROR]" ;;
    esac

    echo -e "${color}${prefix}${NC} $*" >&2
}

# Run Azure CLI with optional debug
run_az_command() {
    if [[ "$AZURE_DEBUG" == "true" ]]; then
        az "$@" --debug
    else
        az "$@"
    fi
}

# Validate required parameters
validate_param() {
    local param_name=$1
    local param_value=$2
    local param_type=${3:-"string"}

    if [[ -z "$param_value" ]]; then
        log ERROR "$param_name is required"
        return 1
    fi

    case $param_type in
        "positive_int")
            if ! [[ "$param_value" =~ ^[0-9]+$ ]] || [[ "$param_value" -lt 1 ]]; then
                log ERROR "$param_name must be a positive integer"
                return 1
            fi
            ;;
        "min_60")
            if ! [[ "$param_value" =~ ^[0-9]+$ ]] || [[ "$param_value" -lt 60 ]]; then
                log ERROR "$param_name must be an integer >= 60"
                return 1
            fi
            ;;
        "file")
            if [[ ! -f "$param_value" ]]; then
                log ERROR "$param_name file not found: $param_value"
                return 1
            fi
            ;;
    esac

    return 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --os)
                OS_TYPE="$2"
                if [[ ! "$OS_TYPE" =~ ^(linux|windows|both)$ ]]; then
                    log ERROR "Invalid OS type: $OS_TYPE. Must be 'linux', 'windows', or 'both'"
                    exit 1
                fi
                shift 2
                ;;
            --deployment-type)
                DEPLOYMENT_TYPE="$2"
                if [[ ! "$DEPLOYMENT_TYPE" =~ ^(vm|vmss|both)$ ]]; then
                    log ERROR "Invalid deployment type: $DEPLOYMENT_TYPE. Must be 'vm', 'vmss', or 'both'"
                    exit 1
                fi
                shift 2
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                validate_param "timeout" "$WAIT_TIMEOUT" "min_60" || exit 1
                shift 2
                ;;
            --location)
                LOCATION="$2"
                validate_param "location" "$LOCATION" || exit 1
                shift 2
                ;;
            --template-file)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            --parameters-file)
                PARAMETERS_FILE="$2"
                shift 2
                ;;
            --subscription-id)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --sensor-update-policy)
                SENSOR_UPDATE_POLICY="$2"
                validate_param "sensor-update-policy" "$SENSOR_UPDATE_POLICY" || exit 1
                shift 2
                ;;
            --disable-cleanup)
                CLEANUP_AFTER_TEST="false"
                shift
                ;;
            --azure-debug)
                AZURE_DEBUG="true"
                shift
                ;;
            --arc)
                ARC_MODE="true"
                shift
                ;;
            --arc-machine-name)
                IFS=',' read -ra _arc_names <<< "$2"
                ARC_MACHINE_NAMES+=("${_arc_names[@]}")
                shift 2
                ;;
            --arc-resource-group)
                ARC_RESOURCE_GROUP="$2"
                shift 2
                ;;
            --skip-cleanup)
                ARC_SKIP_CLEANUP="true"
                CLEANUP_AFTER_TEST="false"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Read OS configurations from config file
read_os_configurations() {
    local filter_os_type="$1"
    local configurations=()

    validate_param "Config file" "$CONFIG_FILE" "file" || return 1

    local current_os="" publisher="" offer="" sku="" version_or_arch=""

    # Add completed configuration to array
    add_config_if_valid() {
        if [[ -n "$current_os" && -n "$publisher" && -n "$offer" && -n "$sku" ]]; then
            # Check if this OS type should be included
            case $filter_os_type in
                "linux") [[ "$current_os" != "Linux" ]] && return ;;
                "windows") [[ "$current_os" != "Windows" ]] && return ;;
                "both") ;; # Include all
            esac

            local config_line="$current_os:$publisher:$offer:$sku"
            [[ -n "$version_or_arch" ]] && config_line="$config_line:$version_or_arch"
            configurations+=("$config_line")
        fi
    }

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        line=$(echo "$line" | xargs)  # Trim whitespace
        [[ -z "$line" ]] && continue

        # Parse key=value pairs
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            case $key in
                "os")
                    add_config_if_valid  # Save previous config
                    current_os="$value"
                    publisher="" offer="" sku="" version_or_arch=""
                    ;;
                "publisher") publisher="$value" ;;
                "offer") offer="$value" ;;
                "sku") sku="$value" ;;
                "architecture"|"version") version_or_arch="$value" ;;
            esac
        fi
    done < "$CONFIG_FILE"

    # Process final configuration
    add_config_if_valid

    if [[ ${#configurations[@]} -eq 0 ]]; then
        log ERROR "No OS configurations found for OS type: $filter_os_type"
        return 1
    fi

    printf '%s\n' "${configurations[@]}"
}

# Format configuration for display
format_config_display() {
    local config=$1
    local os_type=$(echo "$config" | cut -d':' -f1)
    local publisher=$(echo "$config" | cut -d':' -f2)
    local offer=$(echo "$config" | cut -d':' -f3)
    local sku=$(echo "$config" | cut -d':' -f4)
    local version_or_arch=$(echo "$config" | cut -d':' -f5)

    local display="$os_type: $publisher $offer $sku"
    [[ -n "$version_or_arch" ]] && display="$display ($version_or_arch)"
    echo "$display"
}

# Log test result
log_test_result() {
    local result=$1
    local config=$2
    local display=$(format_config_display "$config")

    case $result in
        "PASSED") log SUCCESS "✅ $display: Extension test PASSED" ;;
        "FAILED") log ERROR "❌ $display: Extension test FAILED" ;;
        "DEPLOYMENT_FAILED") log ERROR "❌ $display: Deployment FAILED" ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log INFO "Checking prerequisites..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log ERROR "Azure CLI is not installed"
        exit 1
    fi

    # Check required environment variables
    local required_vars=("SUBSCRIPTION_ID" "FALCON_CLIENT_ID" "FALCON_CLIENT_SECRET")

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log ERROR "$var environment variable is required"
            exit 1
        fi
    done

    # Check Arc-specific prerequisites
    if [[ "$ARC_MODE" == "true" ]]; then
        if [[ ${#ARC_MACHINE_NAMES[@]} -eq 0 ]]; then
            log ERROR "--arc-machine-name is required in Arc mode"
            exit 1
        fi
        if [[ -z "$ARC_RESOURCE_GROUP" ]]; then
            log ERROR "--arc-resource-group is required in Arc mode"
            exit 1
        fi
        log SUCCESS "Prerequisites check passed"
        return
    fi

    if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "both" ]]; then
        validate_param "LINUX_ADMIN_PASSWORD" "$LINUX_ADMIN_PASSWORD" || exit 1
    fi

    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "both" ]]; then
        validate_param "WINDOWS_ADMIN_PASSWORD" "$WINDOWS_ADMIN_PASSWORD" || exit 1
    fi

    # Check required files based on deployment type
    if [[ "$DEPLOYMENT_TYPE" == "vm" || "$DEPLOYMENT_TYPE" == "both" ]]; then
        validate_param "Template file" "$TEMPLATE_FILE" "file" || exit 1
        validate_param "Parameters file" "$PARAMETERS_FILE" "file" || exit 1
        validate_param "Config file" "$CONFIG_FILE" "file" || exit 1
    fi

    if [[ "$DEPLOYMENT_TYPE" == "vmss" || "$DEPLOYMENT_TYPE" == "both" ]]; then
        validate_param "VMSS Template file" "$VMSS_TEMPLATE_FILE" "file" || exit 1
        validate_param "VMSS Parameters file" "$VMSS_PARAMETERS_FILE" "file" || exit 1
    fi

    log SUCCESS "Prerequisites check passed"
}

# Set Azure subscription
set_subscription() {
    log INFO "Setting Azure subscription: $SUBSCRIPTION_ID"
    run_az_command account set -s "$SUBSCRIPTION_ID"
    log SUCCESS "Subscription set successfully"
}

# Get latest extension version
get_latest_extension_version() {
    local os_type=$1

    log INFO "Getting latest extension version for $os_type"

    local versions=$(run_az_command vm extension image list \
        --publisher "$EXTENSION_PUBLISHER" \
        --name "$EXTENSION_NAME" \
        --location "$LOCATION" \
        --query "[].version" \
        --output tsv 2>/dev/null | sort -V | tail -1)

    if [[ -n "$versions" ]]; then
        log INFO "Latest version: $versions"
        echo "$versions"
    else
        log WARNING "No versions found for $EXTENSION_NAME"
        return 1
    fi
}

# Install extension directly
install_extension_direct() {
    local resource_group=$1
    local vm_name=$2
    local os_type=$3
    local version=$4

    log INFO "Installing extension: $EXTENSION_NAME (version: $version)"

    local settings="{}"
    local protected_settings="{\"client_id\":\"$FALCON_CLIENT_ID\",\"client_secret\":\"$FALCON_CLIENT_SECRET\",\"tags\":\"vmextensiontest\",\"sensor_update_policy\":\"$SENSOR_UPDATE_POLICY\"}"

    if run_az_command vm extension set \
        --resource-group "$resource_group" \
        --vm-name "$vm_name" \
        --name "$EXTENSION_NAME" \
        --publisher "$EXTENSION_PUBLISHER" \
        --version "$version" \
        --settings "$settings" \
        --protected-settings "$protected_settings" \
        --output none; then
        log SUCCESS "Extension installation completed"
        return 0
    else
        log ERROR "Extension installation failed"
        return 1
    fi
}

# Check extension status
check_extension_status() {
    local resource_group=$1
    local vm_name=$2
    local deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
    local attempt=1

    log INFO "Checking extension status for VM: $vm_name (timeout: ${WAIT_TIMEOUT}s)"

    while [[ $(date +%s) -lt $deadline ]]; do
        local status=$(run_az_command vm extension show \
            --resource-group "$resource_group" \
            --vm-name "$vm_name" \
            --name "$EXTENSION_NAME" \
            --query "provisioningState" \
            --output tsv 2>/dev/null || echo "NotFound")

        case $status in
            "Succeeded")
                log SUCCESS "Extension installed successfully"
                return 0
                ;;
            "Failed")
                log ERROR "Extension installation failed"
                return 1
                ;;
            "Creating"|"Updating")
                log INFO "Extension installation in progress (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
            "NotFound")
                log WARNING "Extension not found (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
            *)
                log WARNING "Unknown extension status: $status (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
        esac
    done

    log ERROR "Extension status check timed out"
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Azure Arc Extension Testing Functions
# ═══════════════════════════════════════════════════════════════════════════════

# Verify that an Arc machine exists and is connected
check_arc_machine_connectivity() {
    local resource_group=$1
    local machine_name=$2

    log INFO "Checking Arc connectivity for machine: $machine_name"

    local status err
    err=$(mktemp)
    status=$(run_az_command connectedmachine show \
        --resource-group "$resource_group" \
        --name "$machine_name" \
        --query "status" \
        --output tsv 2>"$err") || {
        local error_detail
        error_detail=$(cat "$err")
        rm -f "$err"
        log WARNING "Failed to query machine '$machine_name' in resource group '$resource_group'"
        [[ -n "$error_detail" ]] && log WARNING "$error_detail"
        return 1
    }
    rm -f "$err"

    if [[ "$status" == "Connected" ]]; then
        log SUCCESS "Machine '$machine_name' is connected to Arc"
        return 0
    else
        log WARNING "Machine '$machine_name' status is '$status' (expected 'Connected')"
        return 1
    fi
}

# Determine OS type of an Arc-connected machine
get_arc_machine_os_type() {
    local resource_group=$1
    local machine_name=$2

    run_az_command connectedmachine show \
        --resource-group "$resource_group" \
        --name "$machine_name" \
        --query "osType" \
        --output tsv 2>/dev/null || echo "Unknown"
}

# Deploy the CrowdStrike extension to an Arc-connected machine
deploy_arc_extension() {
    local resource_group=$1
    local machine_name=$2
    local os_type=$3

    local extension_type
    if [[ "$os_type" == "Linux" || "$os_type" == "linux" ]]; then
        extension_type="TestFalconSensorLinux"
    else
        extension_type="TestFalconSensorWindows"
    fi

    local settings='{"disable_provisioning_wait":"true"}'
    local protected_settings="{\"client_id\":\"$FALCON_CLIENT_ID\",\"client_secret\":\"$FALCON_CLIENT_SECRET\",\"tags\":\"arcextensiontest\",\"sensor_update_policy\":\"$SENSOR_UPDATE_POLICY\"}"

    log INFO "Deploying extension '$extension_type' to Arc machine '$machine_name'..."

    if run_az_command connectedmachine extension create \
        --resource-group "$resource_group" \
        --machine-name "$machine_name" \
        --name "$extension_type" \
        --publisher "$EXTENSION_PUBLISHER" \
        --type "$extension_type" \
        --settings "$settings" \
        --protected-settings "$protected_settings" \
        --no-wait \
        --output none; then
        log SUCCESS "Extension deployment initiated for '$machine_name'"
        return 0
    else
        log ERROR "Failed to initiate extension deployment for '$machine_name'"
        return 1
    fi
}

# Poll extension provisioning state on an Arc machine
check_arc_extension_status() {
    local resource_group=$1
    local machine_name=$2
    local extension_name=$3
    local deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
    local attempt=1

    log INFO "Checking Arc extension status for machine: $machine_name (timeout: ${WAIT_TIMEOUT}s)"

    while [[ $(date +%s) -lt $deadline ]]; do
        local status
        status=$(run_az_command connectedmachine extension show \
            --resource-group "$resource_group" \
            --machine-name "$machine_name" \
            --name "$extension_name" \
            --query "properties.provisioningState" \
            --output tsv 2>/dev/null || echo "NotFound")

        case $status in
            "Succeeded")
                log SUCCESS "Arc extension installed successfully on '$machine_name'"
                return 0
                ;;
            "Failed")
                log ERROR "Arc extension installation failed on '$machine_name'"
                local error_msg
                error_msg=$(run_az_command connectedmachine extension show \
                    --resource-group "$resource_group" \
                    --machine-name "$machine_name" \
                    --name "$extension_name" \
                    --query "properties.instanceView.status.message" \
                    --output tsv 2>/dev/null || echo "")
                [[ -n "$error_msg" ]] && log ERROR "Error details: $error_msg"
                return 1
                ;;
            "Creating"|"Updating")
                log INFO "Extension provisioning in progress (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
            "NotFound")
                log WARNING "Extension not found yet (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
            *)
                log WARNING "Unknown extension status: $status (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
        esac
    done

    log ERROR "Arc extension status check timed out for '$machine_name'"
    return 1
}

# Remove the CrowdStrike extension from an Arc machine and wait for removal
cleanup_arc_extension() {
    local resource_group=$1
    local machine_name=$2
    local extension_name=$3

    if [[ "$ARC_SKIP_CLEANUP" == "true" ]]; then
        log WARNING "Skipping cleanup for '$machine_name' (--skip-cleanup enabled)"
        return 0
    fi

    log INFO "Removing extension '$extension_name' from Arc machine '$machine_name'..."

    if ! run_az_command connectedmachine extension delete \
        --resource-group "$resource_group" \
        --machine-name "$machine_name" \
        --name "$extension_name" \
        --yes \
        --no-wait \
        --output none; then
        log WARNING "Failed to remove extension from '$machine_name' (non-fatal)"
        return 0
    fi

    # Wait for extension to be fully removed
    local deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
    local attempt=1

    while [[ $(date +%s) -lt $deadline ]]; do
        if ! run_az_command connectedmachine extension show \
            --resource-group "$resource_group" \
            --machine-name "$machine_name" \
            --name "$extension_name" \
            --output none 2>/dev/null; then
            log SUCCESS "Extension removed from '$machine_name'"
            return 0
        fi
        log INFO "Waiting for extension removal (attempt $attempt)..."
        sleep 30
        ((attempt++))
    done

    log WARNING "Extension removal timed out for '$machine_name' (non-fatal)"
    return 0
}

# Generate VMSS parameters file from template
generate_vmss_parameters_file() {
    local vmss_name=$1
    local os_type=$2
    local publisher=$3
    local offer=$4
    local sku=$5
    local admin_password=$6
    local temp_params=$7

    cp "$VMSS_PARAMETERS_FILE" "$temp_params"

    local os_tag=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')

    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_SECURE_PASSWORD")/$(escape_for_sed "$admin_password")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_CLIENT_ID")/$(escape_for_sed "$FALCON_CLIENT_ID")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_CLIENT_SECRET")/$(escape_for_sed "$FALCON_CLIENT_SECRET")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_SENSOR_UPDATE_POLICY")/$(escape_for_sed "$SENSOR_UPDATE_POLICY")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "CSTestVMSS")/$(escape_for_sed "$vmss_name")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"centraluseuap\"")/$(escape_for_sed "\"$LOCATION\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"Linux\"")/$(escape_for_sed "\"$os_type\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"Canonical\"")/$(escape_for_sed "\"$publisher\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"0001-com-ubuntu-server-jammy\"")/$(escape_for_sed "\"$offer\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"22_04-lts-gen2\"")/$(escape_for_sed "\"$sku\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "vmssextensiontest,linux")/$(escape_for_sed "vmssextensiontest,$os_tag")/g" "$temp_params"
}

# Check VMSS extension status via VMSS provisioning state then instance-level
check_vmss_extension_status() {
    local resource_group=$1
    local vmss_name=$2
    local deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
    local attempt=1

    log INFO "Checking VMSS status for: $vmss_name (timeout: ${WAIT_TIMEOUT}s)"

    # Wait for the VMSS itself to finish provisioning
    while [[ $(date +%s) -lt $deadline ]]; do
        local status=$(run_az_command vmss show \
            --resource-group "$resource_group" \
            --name "$vmss_name" \
            --query "provisioningState" \
            --output tsv 2>/dev/null || echo "NotFound")

        case $status in
            "Succeeded")
                log SUCCESS "VMSS provisioning succeeded"
                check_vmss_instance_extensions "$resource_group" "$vmss_name"
                return $?
                ;;
            "Failed")
                log ERROR "VMSS provisioning failed"
                return 1
                ;;
            "Creating"|"Updating"|"NotFound")
                log INFO "VMSS provisioning in progress (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
            *)
                log WARNING "Unknown VMSS status: $status (attempt $attempt)..."
                sleep 30
                ((attempt++))
                ;;
        esac
    done

    log ERROR "VMSS status check timed out"
    return 1
}

# Check extension status on individual VMSS instances
check_vmss_instance_extensions() {
    local resource_group=$1
    local vmss_name=$2
    local deadline=$(( $(date +%s) + WAIT_TIMEOUT ))

    log INFO "Checking VMSS instance-level extension status..."

    while [[ $(date +%s) -lt $deadline ]]; do
        local ext_codes
        ext_codes=$(run_az_command vmss get-instance-view \
            --resource-group "$resource_group" \
            --name "$vmss_name" \
            --instance-id "*" \
            --query "[].extensions[?name=='$EXTENSION_NAME'][].statuses[0].code" \
            --output tsv 2>/dev/null) || true

        if [[ -z "$ext_codes" ]]; then
            log WARNING "No extension status available yet, waiting..."
            sleep 30
            continue
        fi

        local instance_count=0
        local success_count=0
        local any_failed="false"

        while IFS= read -r code; do
            [[ -z "$code" ]] && continue
            instance_count=$((instance_count + 1))
            if [[ "$code" == *"/succeeded"* ]]; then
                success_count=$((success_count + 1))
            elif [[ "$code" == *"/failed"* ]]; then
                log ERROR "Instance extension status: $code"
                any_failed="true"
            fi
        done <<< "$ext_codes"

        if [[ "$any_failed" == "true" ]]; then
            return 1
        fi

        if [[ $instance_count -gt 0 && $success_count -eq $instance_count ]]; then
            log SUCCESS "All $instance_count VMSS instances report extension success"
            return 0
        fi

        log INFO "Waiting for all instances to complete extension installation ($success_count/$instance_count ready)..."
        sleep 30
    done

    log ERROR "VMSS instance extension check timed out"
    return 1
}

# Generate unique VM name
generate_vm_name() {
    local config=$1
    local os_type=$(echo "$config" | cut -d':' -f1)
    local publisher=$(echo "$config" | cut -d':' -f2)
    local sku=$(echo "$config" | cut -d':' -f4)
    local timestamp=$(date +%H%M%S)

    local vm_name_prefix=$(get_os_config "$os_type" "vm_name_prefix")
    local publisher_clean=$(echo "$publisher" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g')
    local sku_clean=$(echo "$sku" | sed 's/[^a-zA-Z0-9]/-/g')

    local vm_name="${vm_name_prefix}-${publisher_clean}-${sku_clean}-${timestamp}"

    # Ensure VM name doesn't exceed 64 characters
    if [[ ${#vm_name} -gt 64 ]]; then
        local max_sku_len=$((64 - ${#vm_name_prefix} - ${#publisher_clean} - ${#timestamp} - 3))
        if [[ $max_sku_len -gt 0 ]]; then
            sku_clean=$(echo "$sku_clean" | head -c $max_sku_len)
        fi
        vm_name="${vm_name_prefix}-${publisher_clean}-${sku_clean}-${timestamp}"
    fi

    echo "$vm_name"
}

# Cross-platform sed compatibility function
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Escape special characters for sed (bash 3.2 compatible)
escape_for_sed() {
    printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Generate parameters file from template
generate_parameters_file() {
    local vm_name=$1
    local os_type=$2
    local publisher=$3
    local offer=$4
    local sku=$5
    local version_or_arch=$6
    local admin_password=$7
    local temp_params=$8

    # Start with original parameters file
    cp "$PARAMETERS_FILE" "$temp_params"

    # Apply parameter replacements individually (bash 3.2 compatible)
    local computer_name=$(echo "$vm_name" | tr '[:upper:]' '[:lower:]' | head -c 15)
    sed_inplace "s/$(escape_for_sed "\"cstestvm\"")/$(escape_for_sed "\"$computer_name\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_SECURE_PASSWORD")/$(escape_for_sed "$admin_password")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_CLIENT_ID")/$(escape_for_sed "$FALCON_CLIENT_ID")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_CLIENT_SECRET")/$(escape_for_sed "$FALCON_CLIENT_SECRET")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "REPLACE_WITH_SENSOR_UPDATE_POLICY")/$(escape_for_sed "$SENSOR_UPDATE_POLICY")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "CSTestVM")/$(escape_for_sed "$vm_name")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"centraluseuap\"")/$(escape_for_sed "\"$LOCATION\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"Linux\"")/$(escape_for_sed "\"$os_type\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"Canonical\"")/$(escape_for_sed "\"$publisher\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"0001-com-ubuntu-server-jammy\"")/$(escape_for_sed "\"$offer\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"22_04-lts-gen2\"")/$(escape_for_sed "\"$sku\"")/g" "$temp_params"
    sed_inplace "s/$(escape_for_sed "\"x86_64\"")/$(escape_for_sed "\"${version_or_arch:-x86_64}\"")/g" "$temp_params"

    # Arc-specific replacements
    if [[ "$ARC_MODE" == "true" ]]; then
        local machine_name="arc-${vm_name}"
        local computer_name
        computer_name=$(echo "$vm_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | head -c 15)
        sed_inplace "s/$(escape_for_sed "cstest-arc")/$(escape_for_sed "$machine_name")/g" "$temp_params"
        sed_inplace "s/$(escape_for_sed "cstestarc")/$(escape_for_sed "$computer_name")/g" "$temp_params"
        sed_inplace "s/$(escape_for_sed "REPLACE_WITH_ARC_SP_ID")/$(escape_for_sed "$ARC_SERVICE_PRINCIPAL_ID")/g" "$temp_params"
        sed_inplace "s/$(escape_for_sed "REPLACE_WITH_ARC_SP_SECRET")/$(escape_for_sed "$ARC_SERVICE_PRINCIPAL_SECRET")/g" "$temp_params"
    fi
}

# Deploy and test configuration
deploy_and_test_configuration() {
    local config=$1
    local resource_group=$2
    local vm_name=$3
    local deployment_name="deployment-${vm_name}"

    local os_type=$(echo "$config" | cut -d':' -f1)
    local publisher=$(echo "$config" | cut -d':' -f2)
    local offer=$(echo "$config" | cut -d':' -f3)
    local sku=$(echo "$config" | cut -d':' -f4)
    local version_or_arch=$(echo "$config" | cut -d':' -f5)
    local admin_password=$(get_os_config "$os_type" "admin_password")
    local temp_params="/tmp/params-${vm_name}.json"

    # Generate parameters file
    generate_parameters_file "$vm_name" "$os_type" "$publisher" "$offer" "$sku" "$version_or_arch" "$admin_password" "$temp_params"

    # Deploy template
    log INFO "Deploying template..."
    if run_az_command deployment group create \
        --name "$deployment_name" \
        --resource-group "$resource_group" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$temp_params" \
        --output none; then

        log SUCCESS "Deployment completed"
        rm -f "$temp_params"

        # Check extension status
        if check_extension_status "$resource_group" "$vm_name"; then
            log_test_result "PASSED" "$config"
            return 0
        else
            log_test_result "FAILED" "$config"
            return 1
        fi
    else
        log WARNING "Deployment failed, attempting direct extension installation..."
        rm -f "$temp_params"

        # Try direct installation if VM exists
        if run_az_command vm show --resource-group "$resource_group" --name "$vm_name" --output none 2>/dev/null; then
            local latest_version=$(get_latest_extension_version "$os_type")

            if [[ -n "$latest_version" ]] && install_extension_direct "$resource_group" "$vm_name" "$os_type" "$latest_version"; then
                if check_extension_status "$resource_group" "$vm_name"; then
                    log_test_result "PASSED" "$config"
                    return 0
                else
                    log_test_result "FAILED" "$config"
                    return 1
                fi
            else
                log_test_result "FAILED" "$config"
                return 1
            fi
        else
            log_test_result "DEPLOYMENT_FAILED" "$config"
            return 1
        fi
    fi
}

# Test single OS configuration
test_os_configuration() {
    local config=$1
    local resource_group=$2

    log INFO "Testing $(format_config_display "$config")"

    local vm_name=$(generate_vm_name "$config")
    log INFO "VM Name: $vm_name"

    deploy_and_test_configuration "$config" "$resource_group" "$vm_name"
}

# VMSS test configurations (hardcoded — one Linux, one Windows x86_64)
get_vmss_test_configs() {
    local filter_os_type="$1"
    local configs=()

    if [[ "$filter_os_type" == "linux" || "$filter_os_type" == "both" ]]; then
        configs+=("Linux:Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2")
    fi
    if [[ "$filter_os_type" == "windows" || "$filter_os_type" == "both" ]]; then
        configs+=("Windows:MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2")
    fi

    printf '%s\n' "${configs[@]}"
}

# Generate unique VMSS name
generate_vmss_name() {
    local os_type=$1
    local sku=$2
    local timestamp=$(date +%H%M%S)

    local os_tag=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')
    local sku_clean=$(echo "$sku" | sed 's/[^a-zA-Z0-9]/-/g')
    local vmss_name="cstest-vmss-${os_tag}-${sku_clean}-${timestamp}"

    if [[ ${#vmss_name} -gt 64 ]]; then
        vmss_name=$(echo "$vmss_name" | head -c 64)
    fi

    echo "$vmss_name"
}

# Run VMSS tests
run_vmss_tests() {
    local vmss_configs=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && vmss_configs+=("$line")
    done < <(get_vmss_test_configs "$OS_TYPE")

    if [[ ${#vmss_configs[@]} -eq 0 ]]; then
        return 0
    fi

    local total_tests=${#vmss_configs[@]}
    local passed_tests=0
    local failed_tests=0
    local start_time=$(date +%s)

    local timestamp=$(date +%Y%m%d-%H%M%S)
    local resource_group="CS-VMSS-Test-${timestamp}"

    log INFO "Creating VMSS resource group: $resource_group"
    if ! run_az_command group create --name "$resource_group" --location "$LOCATION" --output none; then
        log ERROR "Failed to create VMSS resource group: $resource_group"
        return 1
    fi

    log INFO "Starting VMSS Extension Testing"
    log INFO "OS Type: $OS_TYPE, Total VMSS tests: $total_tests, Location: $LOCATION"
    log INFO "Resource Group: $resource_group, Cleanup: $CLEANUP_AFTER_TEST"
    echo ""

    for config in "${vmss_configs[@]}"; do
        echo "═══════════════════════════════════════════════════"
        local os_type=$(echo "$config" | cut -d':' -f1)
        local publisher=$(echo "$config" | cut -d':' -f2)
        local offer=$(echo "$config" | cut -d':' -f3)
        local sku=$(echo "$config" | cut -d':' -f4)
        local admin_password=$(get_os_config "$os_type" "admin_password")

        local vmss_name=$(generate_vmss_name "$os_type" "$sku")
        local deployment_name="vmss-deployment-${vmss_name}"
        local temp_params="/tmp/vmss-params-${vmss_name}.json"
        local display="VMSS $os_type: $publisher $offer $sku (x86_64)"

        log INFO "Testing $display"
        log INFO "VMSS Name: $vmss_name"

        generate_vmss_parameters_file "$vmss_name" "$os_type" "$publisher" "$offer" "$sku" "$admin_password" "$temp_params"

        log INFO "Deploying VMSS template..."
        if run_az_command deployment group create \
            --name "$deployment_name" \
            --resource-group "$resource_group" \
            --template-file "$VMSS_TEMPLATE_FILE" \
            --parameters "@$temp_params" \
            --output none; then

            log SUCCESS "VMSS deployment completed"
            rm -f "$temp_params"

            if check_vmss_extension_status "$resource_group" "$vmss_name"; then
                log SUCCESS "✅ $display: Extension test PASSED"
                ((passed_tests++))
            else
                log ERROR "❌ $display: Extension test FAILED"
                ((failed_tests++))
            fi
        else
            log ERROR "❌ $display: Deployment FAILED"
            rm -f "$temp_params"
            ((failed_tests++))
        fi
        echo ""
    done

    # Summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local total_minutes=$((total_duration / 60))
    local remaining_seconds=$((total_duration % 60))

    echo "═══════════════════════════════════════════════════"
    log INFO "VMSS TEST SUMMARY"
    echo "Total tests: $total_tests, Passed: $passed_tests, Failed: $failed_tests"
    echo "Duration: ${total_minutes}m ${remaining_seconds}s"
    echo ""

    # Cleanup
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        log INFO "Cleaning up VMSS resource group: $resource_group"
        run_az_command group delete --name "$resource_group" --force-deletion-types Microsoft.Compute/virtualMachineScaleSets --yes --no-wait --output none
        log SUCCESS "VMSS resource group cleanup initiated"
    else
        log WARNING "Keeping VMSS resource group: $resource_group (cleanup disabled)"
    fi

    if [[ $failed_tests -eq 0 ]]; then
        log SUCCESS "🎉 All VMSS tests passed!"
        return 0
    else
        log ERROR "💥 $failed_tests VMSS test(s) failed"
        return 1
    fi
}

# Main testing function
run_tests() {
    local os_configs=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && os_configs+=("$line")
    done < <(read_os_configurations "$OS_TYPE")

    if [[ ${#os_configs[@]} -eq 0 ]]; then
        log ERROR "No configurations available for testing"
        return 1
    fi

    local total_tests=${#os_configs[@]}
    local passed_tests=0
    local failed_tests=0
    local start_time=$(date +%s)

    # Create resource group for all tests
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local resource_group="CS-Extension-Test-${timestamp}"

    log INFO "Creating resource group: $resource_group"
    if ! run_az_command group create --name "$resource_group" --location "$LOCATION" --output none; then
        log ERROR "Failed to create resource group: $resource_group"
        return 1
    fi

    log INFO "Starting Crowdstrike Extension Testing"
    log INFO "OS Type: $OS_TYPE, Total tests: $total_tests, Location: $LOCATION"
    log INFO "Resource Group: $resource_group, Cleanup: $CLEANUP_AFTER_TEST"
    echo ""

    # List configurations
    log INFO "OS configurations to test:"
    for config in "${os_configs[@]}"; do
        echo "  - $(format_config_display "$config")"
    done
    echo ""

    # Run tests
    for config in "${os_configs[@]}"; do
        echo "═══════════════════════════════════════════════════"
        if test_os_configuration "$config" "$resource_group"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
        echo ""
    done

    # Summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local total_minutes=$((total_duration / 60))

    echo "═══════════════════════════════════════════════════"
    log INFO "TEST SUMMARY"
    echo "Total tests: $total_tests, Passed: $passed_tests, Failed: $failed_tests"
    local remaining_seconds=$((total_duration % 60))
    echo "Duration: ${total_minutes}m ${remaining_seconds}s"
    echo ""

    # Cleanup
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        log INFO "Cleaning up resource group: $resource_group"
        run_az_command group delete --name "$resource_group" --force-deletion-types Microsoft.Compute/virtualMachines --yes --no-wait --output none
        log SUCCESS "Resource group cleanup initiated"
    else
        log WARNING "Keeping resource group: $resource_group (cleanup disabled)"
    fi

    if [[ $failed_tests -eq 0 ]]; then
        log SUCCESS "🎉 All tests passed!"
        return 0
    else
        log ERROR "💥 $failed_tests test(s) failed"
        return 1
    fi
}

# Run Arc extension tests against existing connected machines
run_arc_tests() {
    local total_machines=${#ARC_MACHINE_NAMES[@]}
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    local start_time=$(date +%s)

    log INFO "Starting Azure Arc Extension Testing"
    log INFO "Machines: $total_machines, Resource Group: $ARC_RESOURCE_GROUP"
    log INFO "Cleanup: $([[ "$ARC_SKIP_CLEANUP" == "true" ]] && echo "disabled" || echo "enabled")"
    echo ""

    log INFO "Machines to test:"
    for machine in "${ARC_MACHINE_NAMES[@]}"; do
        echo "  - $machine"
    done
    echo ""

    for machine in "${ARC_MACHINE_NAMES[@]}"; do
        echo "═══════════════════════════════════════════════════"
        log INFO "Testing Arc machine: $machine"

        # Step 1: Verify connectivity
        if ! check_arc_machine_connectivity "$ARC_RESOURCE_GROUP" "$machine"; then
            log WARNING "Skipping '$machine' — not connected to Arc"
            ((skipped_tests++))
            echo ""
            continue
        fi

        # Step 2: Determine OS type
        local os_type
        os_type=$(get_arc_machine_os_type "$ARC_RESOURCE_GROUP" "$machine")
        log INFO "Detected OS type: $os_type"

        local extension_name
        if [[ "$os_type" == "Linux" || "$os_type" == "linux" ]]; then
            extension_name="TestFalconSensorLinux"
        else
            extension_name="TestFalconSensorWindows"
        fi

        # Step 3: Deploy extension
        if ! deploy_arc_extension "$ARC_RESOURCE_GROUP" "$machine" "$os_type"; then
            log ERROR "❌ Arc machine '$machine': Extension deployment FAILED"
            ((failed_tests++))
            echo ""
            continue
        fi

        # Step 4: Poll for provisioning state
        if check_arc_extension_status "$ARC_RESOURCE_GROUP" "$machine" "$extension_name"; then
            log SUCCESS "✅ Arc machine '$machine': Extension test PASSED"
            ((passed_tests++))
        else
            log ERROR "❌ Arc machine '$machine': Extension test FAILED"
            ((failed_tests++))
        fi

        # Step 5: Cleanup
        cleanup_arc_extension "$ARC_RESOURCE_GROUP" "$machine" "$extension_name"
        echo ""
    done

    # Summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local total_minutes=$((total_duration / 60))
    local remaining_seconds=$((total_duration % 60))

    echo "═══════════════════════════════════════════════════"
    log INFO "ARC TEST SUMMARY"
    echo "Total machines: $total_machines, Passed: $passed_tests, Failed: $failed_tests, Skipped: $skipped_tests"
    echo "Duration: ${total_minutes}m ${remaining_seconds}s"
    echo ""

    if [[ $failed_tests -eq 0 ]]; then
        if [[ $skipped_tests -gt 0 ]]; then
            log WARNING "All reachable machines passed ($skipped_tests skipped)"
        else
            log SUCCESS "🎉 All Arc tests passed!"
        fi
        return 0
    else
        log ERROR "💥 $failed_tests Arc test(s) failed"
        return 1
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test Crowdstrike Falcon Extension across multiple operating systems

BASIC OPTIONS:
  --os TYPE                 Operating system to test: linux, windows, or both
                            (default: both)
  --deployment-type TYPE    Deployment type to test: vm, vmss, or both
                            (default: both)
  --location LOCATION       Azure region for deployment
                            (default: centraluseuap)
  --disable-cleanup         Disable cleanup of resources after test
  -h, --help                Show this help message

TIMING OPTIONS:
  --timeout SECONDS         Timeout for extension status checks in seconds
                            (default: 1200, minimum: 60)

FILE OPTIONS:
  --template-file PATH      Path to ARM template file
                            (default: ./vm-test-template.json)
  --parameters-file PATH    Path to parameters file
                            (default: ./vm-test-parameters.json)
  --config PATH             Path to test configuration file
                            (default: ./test.config)

ARC OPTIONS:
  --arc                     Enable Azure Arc mode (test existing Arc machines)
  --arc-machine-name NAME   Name of Arc-connected machine to test. Accepts
                            comma-separated values or repeated flags for multiple
                            machines. Required in Arc mode.
  --arc-resource-group RG   Resource group containing the Arc machine(s).
                            Required in Arc mode.
  --skip-cleanup            Leave extension installed after test
                            (default: uninstall after test)

ADVANCED OPTIONS:
  --subscription-id ID      Azure subscription ID
                            (default: AZURE_SUBSCRIPTION_ID env var)
  --sensor-update-policy    Sensor update policy setting
                            (default: platform_default)
  --azure-debug             Enable Azure CLI debug output

REQUIRED ENVIRONMENT VARIABLES:
  AZURE_SUBSCRIPTION_ID     Azure subscription ID
  FALCON_CLIENT_ID          Crowdstrike API client ID
  FALCON_CLIENT_SECRET      Crowdstrike API client secret
  LINUX_ADMIN_PASSWORD      Linux VM admin password (for VM/VMSS tests)
  WINDOWS_ADMIN_PASSWORD    Windows VM admin password (for VM/VMSS tests)

EXAMPLES:
  # Test both VM and VMSS for all operating systems (default)
  $0

  # Test only Linux distributions
  $0 --os linux

  # Test only Windows versions
  $0 --os windows

  # Test only VMs (skip VMSS)
  $0 --deployment-type vm

  # Test only VMSS
  $0 --deployment-type vmss

  # Test VMSS for Linux only
  $0 --deployment-type vmss --os linux

  # Test with cleanup disabled and custom timeout
  $0 --disable-cleanup --timeout 1800

  # Test Linux with custom location
  $0 --os linux --location eastus2

  # Test with custom config file
  $0 --config ./custom-test.config

  # Test extension on an existing Arc-connected machine
  $0 --arc --arc-machine-name myArcMachine --arc-resource-group my-rg

  # Test multiple Arc machines
  $0 --arc --arc-machine-name machine1,machine2 --arc-resource-group my-rg

  # Test Arc machine without cleanup
  $0 --arc --arc-machine-name myMachine --arc-resource-group my-rg --skip-cleanup
EOF
}

# Main script execution
main() {
    parse_arguments "$@"
    check_prerequisites
    set_subscription

    local exit_code=0

    if [[ "$ARC_MODE" == "true" ]]; then
        run_arc_tests || exit_code=1
    else
        if [[ "$DEPLOYMENT_TYPE" == "vm" || "$DEPLOYMENT_TYPE" == "both" ]]; then
            run_tests || exit_code=1
        fi

        if [[ "$DEPLOYMENT_TYPE" == "vmss" || "$DEPLOYMENT_TYPE" == "both" ]]; then
            run_vmss_tests || exit_code=1
        fi
    fi

    exit $exit_code
}

main "$@"
