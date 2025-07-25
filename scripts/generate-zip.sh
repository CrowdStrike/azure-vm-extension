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
    - Test mode: {platform}-handler-test-{version}.zip
    - Publish mode: {platform}-handler-{version}.zip, {platform}-ui-{version}.zip
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
    local zip_name="${platform}-handler${zip_suffix}-${version}.zip"
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    cd "${handler_dir}"
    zip -r "${zip_path}" . -q
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
    local zip_name="${platform}-ui${zip_suffix}-${version}.zip"
    local zip_path="${OUTPUT_DIR}/${zip_name}"
    
    echo "Generating ${zip_name}..."
    
    cd "${package_dir}"
    zip -r "${zip_path}" . -q
    cd "${PROJECT_ROOT}"
    
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
            OUTPUT_DIR="$2"
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
                ((success_count++))
            fi
            ((total_count++))
        else
            echo "Error: Platform directory not found: ${platform}"
        fi
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
