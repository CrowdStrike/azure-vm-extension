#!/usr/bin/env bash

# CrowdStrike Azure VM Extension Zip Generator
# Creates zip packages for test and publish scenarios

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="$(pwd)"

# Default values
TEST_MODE=false
PUBLISH_MODE=false
VERSION=""

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate CrowdStrike Azure VM Extension zip packages

FLAGS:
    --test                              Generate test packages (handler only)
    --publish                           Generate publish packages (handler and UI)
    
OPTIONS:
    -v, --version <version>             Version number (default: 1.0.0)
    -o, --output-dir <directory>        Output directory (default: current directory)
    -h, --help                          Show this help message

EXAMPLES:
    $0 --test                           # Create test handler packages only
    $0 --publish --version 1.2.3       # Create publish packages (handler + UI) with version
    $0 --test --publish -v 2.1.0       # Create both test and publish packages

This script creates zip packages from the handler and package directories:
    - Test mode: csfalcon-{platform}-handler-test-{version}.zip, csfalcon-deployment-test-{version}.zip
    - Publish mode: csfalcon-{platform}-handler-{version}.zip, csfalcon-{platform}-ui-{version}.zip, csfalcon-azure-policy-bicep.zip, csfalcon-deployment-{version}.zip
EOF
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v zip >/dev/null 2>&1; then
        echo "Error: zip command not found. Please install zip utility."
        exit 1
    fi
}

# Function to get version
get_version() {
    if [[ -n "${VERSION}" ]]; then
        echo "${VERSION}"
    else
        echo "1.0.0"
    fi
}

# Function to create handler package
create_handler_package() {
    local platform=$1
    local package_type=$2  # "test" or "publish"
    local version=$3
    
    local platform_dir="${PROJECT_ROOT}/${platform}"
    local handler_dir="${platform_dir}/handler"
    
    if [[ ! -d "${handler_dir}" ]]; then
        echo "Error: Handler directory not found: ${handler_dir}"
        return 1
    fi
    
    # Create zip file in output directory
    local zip_suffix=""
    if [[ "${package_type}" == "test" ]]; then
        zip_suffix="-test"
    fi
    local zip_name="csfalcon-${platform}-handler${zip_suffix}-${version}.zip"
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    cd "${handler_dir}" || {
        echo "Error: Failed to change to handler directory: ${handler_dir}"
        return 1
    }
    
    if ! zip -r "${zip_path}" . -q; then
        echo "Error: Failed to create zip file: ${zip_path}"
        cd "${PROJECT_ROOT}"
        return 1
    fi
    
    cd "${PROJECT_ROOT}"
    
    echo "✓ Created ${zip_name}"
    return 0
}

# Function to create UI package
create_ui_package() {
    local platform=$1
    local package_type=$2  # "test" or "publish"
    local version=$3
    
    local platform_dir="${PROJECT_ROOT}/${platform}"
    local package_dir="${platform_dir}/package"
    
    if [[ ! -d "${package_dir}" ]]; then
        echo "Error: Package directory not found: ${package_dir}"
        return 1
    fi
    
    # Create zip file in output directory
    local zip_suffix=""
    if [[ "${package_type}" == "test" ]]; then
        zip_suffix="-test"
    fi
    local zip_name="csfalcon-${platform}-ui${zip_suffix}-${version}.zip"
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    cd "${package_dir}" || {
        echo "Error: Failed to change to package directory: ${package_dir}"
        return 1
    }
    
    if ! zip -r "${zip_path}" . -q; then
        echo "Error: Failed to create zip file: ${zip_path}"
        cd "${PROJECT_ROOT}"
        return 1
    fi
    
    cd "${PROJECT_ROOT}"
    
    echo "✓ Created ${zip_name}"
    return 0
}

# Function to create policy package
create_policy_package() {
    local package_type=$1  # "test" or "publish"
    local version=$2
    
    local policy_dir="${PROJECT_ROOT}/policy"
    
    if [[ ! -d "${policy_dir}" ]]; then
        echo "Error: Policy directory not found: ${policy_dir}"
        return 1
    fi
    
    # Create zip file in output directory
    local zip_name="csfalcon-azure-policy-bicep.zip"
    if [[ "${package_type}" == "test" ]]; then
        zip_name="csfalcon-azure-policy-bicep-test-${version}.zip"
    fi
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    cd "${policy_dir}" || {
        echo "Error: Failed to change to policy directory: ${policy_dir}"
        return 1
    }
    
    if ! zip -r "${zip_path}" . -x "ui*.json" -q; then
        echo "Error: Failed to create zip file: ${zip_path}"
        cd "${PROJECT_ROOT}"
        return 1
    fi
    
    cd "${PROJECT_ROOT}"
    
    echo "✓ Created ${zip_name}"
    return 0
}

# Function to create deployment package
create_deployment_package() {
    local package_type=$1  # "test" or "publish"
    local version=$2
    
    # Create zip file in output directory
    local zip_suffix=""
    if [[ "${package_type}" == "test" ]]; then
        zip_suffix="-test"
    fi
    local zip_name="csfalcon-publish${zip_suffix}-extension-${version}.zip"
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    # Create temporary directory for deployment files
    local temp_dir=$(mktemp -d)
    
    # Copy deployment files to temp directory
    if [[ "${package_type}" == "test" ]]; then
        # For test mode, look for test deployment files
        if [[ -f "${PROJECT_ROOT}/test-linux-extension.json" ]]; then
            cp "${PROJECT_ROOT}/test-linux-extension.json" "${temp_dir}/"
        fi
        if [[ -f "${PROJECT_ROOT}/test-windows-extension.json" ]]; then
            cp "${PROJECT_ROOT}/test-windows-extension.json" "${temp_dir}/"
        fi
    else
        # For publish mode, look for publish deployment files
        if [[ -f "${PROJECT_ROOT}/publish-linux-extension.json" ]]; then
            cp "${PROJECT_ROOT}/publish-linux-extension.json" "${temp_dir}/"
        fi
        if [[ -f "${PROJECT_ROOT}/publish-windows-extension.json" ]]; then
            cp "${PROJECT_ROOT}/publish-windows-extension.json" "${temp_dir}/"
        fi
    fi
    
    # Check if we have any files to package
    if [[ -z "$(ls -A ${temp_dir})" ]]; then
        echo "Error: No deployment files found to package"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Create zip from temp directory
    cd "${temp_dir}" || {
        echo "Error: Failed to change to temp directory: ${temp_dir}"
        rm -rf "${temp_dir}"
        return 1
    }
    
    if ! zip -r "${zip_path}" . -q; then
        echo "Error: Failed to create zip file: ${zip_path}"
        cd "${PROJECT_ROOT}"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    cd "${PROJECT_ROOT}"
    rm -rf "${temp_dir}"
    
    echo "✓ Created ${zip_name}"
    return 0
}

# Function to create packages for a platform
create_platform_packages() {
    local platform=$1
    local package_types=("$@")
    package_types=("${package_types[@]:1}")  # Remove first element (platform)
    
    local version
    version=$(get_version)
    
    local success=true
    for package_type in "${package_types[@]}"; do
        # Always create handler package
        if ! create_handler_package "${platform}" "${package_type}" "${version}"; then
            success=false
        fi
        
        # Only create UI package for publish mode
        if [[ "${package_type}" == "publish" ]]; then
            if ! create_ui_package "${platform}" "${package_type}" "${version}"; then
                success=false
            fi
        fi
    done
    
    if [[ "${success}" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_MODE=true
            shift
            ;;
        --publish)
            PUBLISH_MODE=true
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -o|--output-dir)
            mkdir -p "$2"
            OUTPUT_DIR="$(cd "$2" && pwd)"  # Convert to absolute path
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ "${TEST_MODE}" == false && "${PUBLISH_MODE}" == false ]]; then
    echo "Error: Must specify either --test or --publish (or both)"
    show_usage
    exit 1
fi

# Main execution
main() {
    # Check prerequisites
    check_prerequisites
    
    # Get version
    local version
    version=$(get_version)
    
    # Determine package types to build
    local package_types=()
    if [[ "${TEST_MODE}" == true ]]; then
        package_types+=("test")
    fi
    if [[ "${PUBLISH_MODE}" == true ]]; then
        package_types+=("publish")
    fi
    
    echo "Generating zip packages..."
    if [[ "${TEST_MODE}" == true && "${PUBLISH_MODE}" == false ]]; then
        echo "Mode: test (handler packages only)"
    elif [[ "${TEST_MODE}" == false && "${PUBLISH_MODE}" == true ]]; then
        echo "Mode: publish (handler and UI packages)"
    else
        echo "Mode: test and publish"
    fi
    echo "Version: ${version}"
    echo "Output directory: ${OUTPUT_DIR}"
    echo ""
    
    # Create output directory if it doesn't exist
    mkdir -p "${OUTPUT_DIR}"
    
    # Create packages for both platforms
    local platforms=("linux" "windows")
    local success_count=0
    local total_count=0
    
    for platform in "${platforms[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${platform}" ]]; then
            if create_platform_packages "${platform}" "${package_types[@]}"; then
                echo "✓ Successfully created packages for ${platform}"
                success_count=$((success_count + 1))
            else
                echo "✗ Failed to create packages for ${platform}"
            fi
            total_count=$((total_count + 1))
        else
            echo "Error: Platform directory not found: ${platform}"
        fi
    done
    
    # Create policy package (only in publish mode)
    if [[ "${PUBLISH_MODE}" == true ]]; then
        echo ""
        if create_policy_package "publish" "${version}"; then
            echo "✓ Successfully created policy package"
            success_count=$((success_count + 1))
        else
            echo "✗ Failed to create policy package"
        fi
        total_count=$((total_count + 1))
    fi
    
    # Create deployment package
    echo ""
    for package_type in "${package_types[@]}"; do
        if create_deployment_package "${package_type}" "${version}"; then
            echo "✓ Successfully created deployment package"
            success_count=$((success_count + 1))
        else
            echo "✗ Failed to create deployment package"
        fi
        total_count=$((total_count + 1))
    done
    
    echo ""
    if [[ ${success_count} -eq ${total_count} ]]; then
        echo "Zip package generation completed!"
        exit 0
    else
        echo "Error: Some packages failed to build (${success_count}/${total_count} platforms succeeded)"
        exit 1
    fi
}

# Run main function
main "$@"
