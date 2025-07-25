#!/bin/bash

# Crowdstrike VM Extension Multi-OS Testing Script
# This script deploys and tests the Crowdstrike Falcon extension across multiple operating systems

set -euo pipefail

# Default configuration
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
LOCATION="centraluseuap"
TEMPLATE_FILE="./vm-test-template.json"
PARAMETERS_FILE="./vm-test-parameters.json"
CONFIG_FILE="./test.config"

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
MAX_ATTEMPTS=30
AZURE_DEBUG="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# OS configuration mapping
declare -A OS_CONFIG=(
    ["Linux:admin_password"]="$LINUX_ADMIN_PASSWORD"
    ["Linux:resource_group_prefix"]="CS-Linux-Test"
    ["Linux:vm_name_prefix"]="cstest"
    ["Windows:admin_password"]="$WINDOWS_ADMIN_PASSWORD"
    ["Windows:resource_group_prefix"]="CS-Windows-Test"
    ["Windows:vm_name_prefix"]="cstest"
)

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
            --timeout)
                WAIT_TIMEOUT="$2"
                validate_param "timeout" "$WAIT_TIMEOUT" "positive_int" || exit 1
                shift 2
                ;;
            --max-attempts)
                MAX_ATTEMPTS="$2"
                validate_param "max-attempts" "$MAX_ATTEMPTS" "positive_int" || exit 1
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

# Get OS-specific configuration value
get_os_config() {
    local os_type=$1
    local config_key=$2
    echo "${OS_CONFIG[$os_type:$config_key]:-}"
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
    
    # Check OS-specific passwords
    if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "both" ]]; then
        validate_param "LINUX_ADMIN_PASSWORD" "$LINUX_ADMIN_PASSWORD" || exit 1
    fi
    
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "both" ]]; then
        validate_param "WINDOWS_ADMIN_PASSWORD" "$WINDOWS_ADMIN_PASSWORD" || exit 1
    fi
    
    # Check required files
    validate_param "Template file" "$TEMPLATE_FILE" "file" || exit 1
    validate_param "Parameters file" "$PARAMETERS_FILE" "file" || exit 1
    validate_param "Config file" "$CONFIG_FILE" "file" || exit 1
    
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
    local attempt=1
    
    log INFO "Checking extension status for VM: $vm_name"
    
    while [[ $attempt -le $MAX_ATTEMPTS ]]; do
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
                log INFO "Extension installation in progress (attempt $attempt/$MAX_ATTEMPTS)..."
                sleep 30
                ((attempt++))
                ;;
            "NotFound")
                log WARNING "Extension not found (attempt $attempt/$MAX_ATTEMPTS)..."
                sleep 30
                ((attempt++))
                ;;
            *)
                log WARNING "Unknown extension status: $status (attempt $attempt/$MAX_ATTEMPTS)..."
                sleep 30
                ((attempt++))
                ;;
        esac
    done
    
    log ERROR "Extension status check timed out"
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
    
    # Use associative array for cleaner parameter replacement
    declare -A replacements=(
        ["REPLACE_WITH_SECURE_PASSWORD"]="$admin_password"
        ["REPLACE_WITH_CLIENT_ID"]="$FALCON_CLIENT_ID"
        ["REPLACE_WITH_CLIENT_SECRET"]="$FALCON_CLIENT_SECRET"
        ["REPLACE_WITH_SENSOR_UPDATE_POLICY"]="$SENSOR_UPDATE_POLICY"
        ["CSTestVM"]="$vm_name"
        ["\"centraluseuap\""]="\"$LOCATION\""
        ["\"Linux\""]="\"$os_type\""
        ["\"Canonical\""]="\"$publisher\""
        ["\"0001-com-ubuntu-server-jammy\""]="\"$offer\""
        ["\"22_04-lts-gen2\""]="\"$sku\""
        ["\"x86_64\""]="\"${version_or_arch:-x86_64}\""
    )
    
    # Start with original parameters file
    cp "$PARAMETERS_FILE" "$temp_params"
    
    # Apply replacements
    for search in "${!replacements[@]}"; do
        local replace="${replacements[$search]}"
        # Escape special characters for sed
        local escaped_search=$(printf '%s\n' "$search" | sed 's/[[\.*^$()+?{|]/\\&/g')
        local escaped_replace=$(printf '%s\n' "$replace" | sed 's/[[\.*^$(){}+?|/]/\\&/g')
        sed -i "s/$escaped_search/$escaped_replace/g" "$temp_params"
    done
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
    echo "Duration: ${total_minutes}m ${total_duration}s"
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

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test Crowdstrike Falcon Extension across multiple operating systems

BASIC OPTIONS:
  --os TYPE                 Operating system to test: linux, windows, or both
                            (default: both)
  --location LOCATION       Azure region for deployment 
                            (default: centraluseuap)
  --disable-cleanup         Disable cleanup of resources after test
  -h, --help                Show this help message

TIMING OPTIONS:
  --timeout SECONDS         Timeout for deployment operations in seconds
                            (default: 1200)
  --max-attempts NUMBER     Maximum attempts for extension status checks
                            (default: 30)

FILE OPTIONS:
  --template-file PATH      Path to ARM template file
                            (default: ./vm-test-template.json)
  --parameters-file PATH    Path to parameters file
                            (default: ./vm-test-parameters.json)
  --config PATH             Path to test configuration file
                            (default: ./test.config)

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
  LINUX_ADMIN_PASSWORD      Linux VM admin password (for Linux tests)
  WINDOWS_ADMIN_PASSWORD    Windows VM admin password (for Windows tests)

EXAMPLES:
  # Test both Linux and Windows
  $0

  # Test only Linux distributions
  $0 --os linux

  # Test only Windows versions
  $0 --os windows

  # Test with cleanup disabled and custom timeout
  $0 --disable-cleanup --timeout 1800

  # Test Linux with custom location
  $0 --os linux --location eastus2

  # Test with custom config file
  $0 --config-file ./custom-test.config
EOF
}

# Main script execution
main() {
    parse_arguments "$@"
    check_prerequisites
    set_subscription
    run_tests
}

main "$@"
