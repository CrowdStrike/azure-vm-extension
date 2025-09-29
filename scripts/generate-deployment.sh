#!/usr/bin/env bash

# CrowdStrike Azure VM Extension Deployment JSON Generator
# This script generates ARM deployment templates using a template file

set -euo pipefail

# Default values
TEST_MODE=false
PUBLISH_MODE=false
PLATFORM="all"
VERSION=""
REGIONS=""
TEMPLATE_FILE="deploy.json.template"
OUTPUT_DIR="$(pwd)"

# Helper function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate CrowdStrike Azure VM Extension deployment JSON files

FLAGS:
    --test                              Generate test deployment files
    --publish                           Generate publish deployment files
    
OPTIONS:
    -p, --platform <linux|windows|all> Platform (default: all)
    -v, --version <version>             Version number (required)
    -r, --regions <region1,region2,...> Comma-separated regions (only with --publish)
    -t, --template-file <file>          Template file path (default: deploy.json.template)
    -o, --output-dir <directory>        Output directory (default: current directory)
    -h, --help                          Show this help message

EXAMPLES:
    $0 --publish -v 1.0.0 -p all -r "Central US EUAP,South Central US"
    $0 --test -v 0.0.0.1 -p linux
    $0 --publish -v 1.2.3 -p windows -r "Central US EUAP"
    $0 --test -v 0.0.0.12 -p all -o ./deployment-files
    $0 --publish -v 1.0.0 -p linux -o /tmp/azure-deployments

This script reads from $TEMPLATE_FILE and generates deployment files in the specified output directory:
    - Publish mode: deploy-linux.json, deploy-windows.json
    - Test mode: test-linux.json, test-windows.json
EOF
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
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--regions)
            REGIONS="$2"
            shift 2
            ;;
        -t|--template-file)
            TEMPLATE_FILE="$2"
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
if [[ "$TEST_MODE" == true && "$PUBLISH_MODE" == true ]]; then
    echo "Error: Cannot specify both --test and --publish"
    exit 1
fi

if [[ "$TEST_MODE" == false && "$PUBLISH_MODE" == false ]]; then
    echo "Error: Must specify either --test or --publish"
    exit 1
fi

if [[ ! "$PLATFORM" =~ ^(linux|windows|all)$ ]]; then
    echo "Error: Platform must be 'linux', 'windows', or 'all'"
    exit 1
fi

if [[ -z "$VERSION" ]]; then
    echo "Error: Version is required"
    show_usage
    exit 1
fi

# Validate test version format
if [[ "$TEST_MODE" == true && ! "$VERSION" =~ ^0\.0\.0\.[0-9]+$ ]]; then
    echo "Error: Test mode version must be in format 0.0.0.[digits] (e.g., 0.0.0.1, 0.0.0.123)"
    exit 1
fi

if [[ "$TEST_MODE" == true && -n "$REGIONS" ]]; then
    echo "Error: --regions flag can only be used with --publish"
    exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template file $TEMPLATE_FILE not found"
    exit 1
fi

# Set environment based on flags
ENVIRONMENT=""
if [[ "$TEST_MODE" == true ]]; then
    ENVIRONMENT="test"
elif [[ "$PUBLISH_MODE" == true ]]; then
    ENVIRONMENT="publish"
fi

echo "Generating deployment files..."
echo "Mode: $ENVIRONMENT"
echo "Platform: $PLATFORM"
echo "Version: $VERSION"
echo "Output directory: $OUTPUT_DIR"
if [[ -n "$REGIONS" ]]; then
    echo "Regions: $REGIONS"
fi
echo ""

# Function to format regions for JSON
format_regions() {
    local regions_input="$1"
    local default_array="$2"
    
    if [[ -n "$regions_input" ]]; then
        # Split by comma and format each region with quotes
        IFS=',' read -ra REGION_ARRAY <<< "$regions_input"
        local formatted_regions="["
        local first=true
        for region in "${REGION_ARRAY[@]}"; do
            # Trim whitespace
            region=$(echo "$region" | xargs)
            if [[ "$first" == true ]]; then
                formatted_regions="$formatted_regions\"$region\""
                first=false
            else
                formatted_regions="$formatted_regions, \"$region\""
            fi
        done
        formatted_regions="$formatted_regions]"
        echo "$formatted_regions"
    else
        echo "$default_array"
    fi
}

# Function to generate deployment file for a specific platform/environment combination
generate_deployment() {
    local platform=$1
    local env=$2
    local output_file=$3
    
    echo "Generating $output_file..."
    
    # Determine values based on platform and environment
    local type_name=""
    local label=""
    local description=""
    local media_link=""
    local regions=""
    local supported_os=""
    local internal_extension=""
    
    # Set internal extension flag based on environment
    if [[ "$env" == "test" ]]; then
        regions='["Central US EUAP"]'
        internal_extension="true"
    else
        # For publish mode, use provided regions or default
        local default_array='["*"]'
        regions=$(format_regions "$REGIONS" "$default_array")
        internal_extension="false"
    fi
    
    if [[ "$platform" == "linux" ]]; then
        supported_os="Linux"
        if [[ "$env" == "test" ]]; then
            type_name="TestFalconSensorLinux"
            label="Test Extension for the CrowdStrike Falcon Sensor for Linux"
            description="CrowdStrike Falcon Sensor for Linux Test Extension"
            media_link="https://vmextensiontest.blob.core.windows.net/extensions/testlinuxextension-${VERSION}.zip"
        else
            type_name="FalconSensorLinux"
            label="CrowdStrike Falcon Sensor for Linux VM Extension"
            description="CrowdStrike Falcon Sensor for Linux provides real-time protection, detection, and response capabilities for Linux virtual machines, detecting advanced threats and stopping breaches."
            media_link="https://publishvmextension.blob.core.windows.net/extensions/csfalcon-linux-handler-${VERSION}.zip"
        fi
    else # windows
        supported_os="Windows"
        if [[ "$env" == "test" ]]; then
            type_name="TestFalconSensorWindows"
            label="Test Extension for the CrowdStrike Falcon Sensor for Windows"
            description="CrowdStrike Falcon Sensor for Windows Test Extension"
            media_link="https://vmextensiontest.blob.core.windows.net/extensions/testwindowsextension-${VERSION}.zip"
        else
            type_name="FalconSensorWindows"
            label="CrowdStrike Falcon Sensor for Windows VM Extension"
            description="CrowdStrike Falcon Sensor for Windows provides real-time protection, detection, and response capabilities for Windows virtual machines, detecting advanced threats and stopping breaches."
            media_link="https://publishvmextension.blob.core.windows.net/extensions/csfalcon-windows-handler-${VERSION}.zip"
        fi
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Generate the deployment file by replacing placeholders
    sed -e "s|{{TYPE_NAME}}|$type_name|g" \
        -e "s|{{LABEL}}|$label|g" \
        -e "s|{{DESCRIPTION}}|$description|g" \
        -e "s|{{VERSION}}|$VERSION|g" \
        -e "s|{{MEDIA_LINK}}|$media_link|g" \
        -e "s|\"REGIONS_PLACEHOLDER\"|$regions|g" \
        -e "s|{{SUPPORTED_OS}}|$supported_os|g" \
        -e "s|{{INTERNAL_EXTENSION}}|$internal_extension|g" \
        "$TEMPLATE_FILE" > "$output_file"
    
    echo "✓ Created $output_file"
}

# Generate files based on platform selection
if [[ "$PLATFORM" == "all" || "$PLATFORM" == "linux" ]]; then
    if [[ "$ENVIRONMENT" == "test" ]]; then
        generate_deployment "linux" "test" "$OUTPUT_DIR/test-linux-extension.json"
    else
        generate_deployment "linux" "publish" "$OUTPUT_DIR/publish-linux-extension.json"
    fi
fi

if [[ "$PLATFORM" == "all" || "$PLATFORM" == "windows" ]]; then
    if [[ "$ENVIRONMENT" == "test" ]]; then
        generate_deployment "windows" "test" "$OUTPUT_DIR/test-windows-extension.json"
    else
        generate_deployment "windows" "publish" "$OUTPUT_DIR/publish-windows-extension.json"
    fi
fi

echo ""
echo "Deployment file generation completed!"
