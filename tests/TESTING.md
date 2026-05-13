# Crowdstrike VM Extension Testing

This directory contains testing tools for the Crowdstrike Falcon VM Extension that supports both Linux and Windows operating systems on VMs and VM Scale Sets (VMSS).

## Overview

The testing framework allows you to:
- Deploy VMs with the Crowdstrike Falcon extension across multiple operating systems
- Deploy VMSS with the Crowdstrike Falcon extension (one Linux, one Windows x86_64)
- Test Linux distributions (Ubuntu, Debian, RHEL, SLES) with x86_64 and arm64 architectures
- Test Windows Server versions (2019, 2022, Core editions, Azure editions)
- Run tests for specific platforms or all platforms
- Verify extension installation and generate detailed reports
- Control resource cleanup behavior

## Files

- **`test-extension.sh`** - Main testing script for both Linux and Windows
- **`vm-test-template.json`** - ARM template for VM creation and extension deployment
- **`vm-test-parameters.json`** - VM parameters template file
- **`vmss-test-template.json`** - ARM template for VMSS creation and extension deployment
- **`vmss-test-parameters.json`** - VMSS parameters template file
- **`test.config`** - OS configurations for VM tests (key=value format)

## Prerequisites

1. **Azure CLI** installed and configured
2. **Azure subscription** with VM creation permissions
3. **Crowdstrike API credentials** with scopes:
   - Sensor Download [read]
   - Sensor update policies [read]
   - (Optional) Installation Tokens [read]
4. **Test extensions** deployed to your subscription:
   - `TestFalconSensorLinux` for Linux testing
   - `TestFalconSensorWindows` for Windows testing

## Setup

### Environment Variables

```bash
# Required for all tests
export AZURE_SUBSCRIPTION_ID='your-subscription-id'
export FALCON_CLIENT_ID='your-crowdstrike-client-id'
export FALCON_CLIENT_SECRET='your-crowdstrike-client-secret'

# Required for Linux tests
export LINUX_ADMIN_PASSWORD='SecureLinuxPass123!'

# Required for Windows tests
export WINDOWS_ADMIN_PASSWORD='SecureWindowsPass123!'
```

## Usage

### Basic Commands

```bash
# Test both VM and VMSS for all operating systems (default)
./test-extension.sh

# Test only Linux distributions
./test-extension.sh --os linux

# Test only Windows versions
./test-extension.sh --os windows

# Test only VMs (skip VMSS)
./test-extension.sh --deployment-type vm

# Test only VMSS
./test-extension.sh --deployment-type vmss

# Test VMSS for Linux only
./test-extension.sh --deployment-type vmss --os linux

# Keep resources for debugging
./test-extension.sh --disable-cleanup
```

### Advanced Options

```bash
# Custom timeout (seconds)
./test-extension.sh --timeout 1800

# Different Azure region
./test-extension.sh --location eastus2

# Custom config file
./test-extension.sh --config custom-test.config

# Combine options
./test-extension.sh --os linux --location westus2 --disable-cleanup
```

### Command Line Options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--os` | `linux`, `windows`, `both` | `both` | Operating system(s) to test |
| `--deployment-type` | `vm`, `vmss`, `both` | `both` | Deployment type(s) to test |
| `--timeout` | seconds (≥60) | `1200` | Timeout for extension status checks |
| `--location` | region | `centraluseuap` | Azure region for deployment |
| `--template-file` | path | `vm-test-template.json` | Path to ARM template file |
| `--parameters-file` | path | `vm-test-parameters.json` | Path to parameters file |
| `--subscription-id` | uuid | `$AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `--config` | path | `./test.config` | Path to test configuration file |
| `--disable-cleanup` | - | false | Disable cleanup of resources after tests |
| `-h`, `--help` | - | - | Show help message |

## Configuration

### Test Configuration File (`test.config`)

The configuration file contains OS definitions in key=value format:

```bash
# Ubuntu 22.04 LTS x86_64
os=Linux
publisher=Canonical
offer=0001-com-ubuntu-server-jammy
sku=22_04-lts-gen2
architecture=x86_64

# Ubuntu 22.04 LTS arm64
os=Linux
publisher=Canonical
offer=0001-com-ubuntu-server-jammy
sku=22_04-lts-arm64
architecture=arm64

# Windows Server 2022 Datacenter
os=Windows
publisher=MicrosoftWindowsServer
offer=WindowsServer
sku=2022-datacenter-g2
version=latest
```

**Linux configurations require:** `os=Linux`, `publisher`, `offer`, `sku`, `architecture`
**Windows configurations require:** `os=Windows`, `publisher`, `offer`, `sku`, `version`

## Test Process

### VM Tests

For each OS configuration in `test.config`, the script:

1. **Creates** a dedicated resource group
2. **Deploys** the ARM template with OS-specific parameters
3. **Waits** for VM and extension deployment completion
4. **Verifies** extension installation status
5. **Reports** success or failure
6. **Cleans up** resources (unless disabled)

### VMSS Tests

The script runs two fixed VMSS deployments (one Linux, one Windows x86_64):

1. **Creates** a dedicated resource group for VMSS tests
2. **Deploys** the VMSS ARM template with OS-specific parameters
3. **Waits** for VMSS extension provisioning at the model level
4. **Verifies** extension installation on individual instances
5. **Reports** success or failure
6. **Cleans up** resources (unless disabled)

## Output Examples

### Successful Test Run

```bash
$ ./test-extension.sh --os linux
[INFO] Starting Crowdstrike Extension Testing
[INFO] OS Type: linux
[INFO] Total tests: 15 (Linux: 15, Windows: 0)
[INFO] Location: centraluseuap

═══════════════════════════════════════════════════
[INFO] Testing Linux OS: Canonical 0001-com-ubuntu-server-jammy 22_04-lts-gen2 (x86_64)
[SUCCESS] Deployment completed in 245s
[SUCCESS] Extension installed successfully
[SUCCESS] ✅ Ubuntu 22.04 LTS (x86_64): Extension test PASSED

═══════════════════════════════════════════════════
TEST SUMMARY
OS Type: linux
Total tests: 15 (Linux: 15, Windows: 0)
Passed: 15
Failed: 0
Duration: 42m 30s

[SUCCESS] 🎉 All tests passed!
```

## Debugging

### Keep Resources for Investigation

```bash
./test-extension.sh --disable-cleanup
```

### Check Extension Status

```bash
# Linux example
az vm extension show \
  --resource-group CS-Linux-Test-canonical-22-04-lts-gen2-x86-64 \
  --vm-name cstest-canonical-22-04-lts-gen2-x86-64 \
  --name CrowdstrikeFalconSensor

# Windows example
az vm extension show \
  --resource-group CS-Windows-Test-microsoftwindowsserver-2022-datacenter-g2 \
  --vm-name cstest-microsoftwindowsserver-2022-datacenter-g2 \
  --name CrowdstrikeFalconSensor
```

### Review VM Logs

```bash
# Linux - Check systemd logs
az vm run-command invoke \
  --resource-group CS-Linux-Test-canonical-22-04-lts-gen2-x86-64 \
  --name cstest-canonical-22-04-lts-gen2-x86-64 \
  --command-id RunShellScript \
  --scripts "sudo journalctl -u crowdstrike-falcon.service -n 50"

# Windows - Check event logs via Azure portal
```

## Customization

### Adding New Linux Distributions

1. Find Azure image details:
   ```bash
   az vm image list --publisher Canonical --offer 0001-com-ubuntu-server-mantic --all --output table
   ```

2. Add to `test.config`:
   ```bash
   # Ubuntu 23.10 x86_64
   os=Linux
   publisher=Canonical
   offer=0001-com-ubuntu-server-mantic
   sku=23_10-daily-gen2
   architecture=x86_64
   ```

### Adding New Windows Versions

1. Find Azure image details:
   ```bash
   az vm image list --publisher MicrosoftWindowsServer --offer WindowsServer --all --output table
   ```

2. Add to `test.config`:
   ```bash
   # Windows Server 2025 Preview
   os=Windows
   publisher=MicrosoftWindowsServer
   offer=WindowsServer
   sku=2025-datacenter-preview
   version=latest
   ```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Extension not found | Ensure test extensions are deployed to your subscription |
| Authentication failed | Verify Crowdstrike API credentials |
| VM creation failed | Check Azure quota limits |
| Deployment timeout | Use `--timeout` parameter to increase wait time |
| Resource group conflicts | Use `--disable-cleanup` to investigate |

### Debug Commands

```bash
# Check available VM sizes for ARM64
az vm list-sizes --location centraluseuap --query "[?contains(name, 'ps_v5')]"

# Verify extension availability
az vm extension image list --publisher Crowdstrike.Falcon --location centraluseuap

# List all test resource groups
az group list --query "[?starts_with(name, 'CS-')].name" --output table

# Check deployment status
az deployment group show \
  --resource-group CS-Linux-Test-canonical-22-04-lts-gen2-x86-64 \
  --name deployment-20250717-120000
```

## Security Features

The testing setup includes:
- **Network Security Groups** with explicit denial of all inbound traffic
- **No SSH or RDP access** - VMs are only accessible via Azure management plane
- **Proper isolation** for testing scenarios

## Architecture

```
tests/
├── test-extension.sh              # Main test script (VM + VMSS)
├── vm-test-template.json          # VM ARM template
├── vm-test-parameters.json        # VM parameters
├── vmss-test-template.json        # VMSS ARM template
├── vmss-test-parameters.json      # VMSS parameters
├── test.config                    # VM OS configurations
└── TESTING.md                     # This documentation
```

The script follows this flow:
1. Parse command line options
2. **VM tests**: Read and filter OS configurations from `test.config`, deploy each as a single VM
3. **VMSS tests**: Deploy one Linux and one Windows x86_64 VMSS using fixed configurations
4. Generate unified test summary
