# CrowdStrike Azure VM Extension

The CrowdStrike Azure VM Extension is an open-source solution that simplifies and automates the installation of the CrowdStrike Falcon sensor on Azure virtual machines at enterprise scale.

## Overview

The CrowdStrike Azure VM Extension provides:

- **Automated Deployment**: Deploy the Falcon sensor to Azure VMs at scale using Azure's native extension framework
- **Cross-Platform Support**: Support for both Linux and Windows Azure virtual machines
- **Enterprise Integration**: Seamless integration with Azure infrastructure and CrowdStrike APIs
- **Lifecycle Management**: Handle sensor installation, configuration, updates, and removal
- **Architecture Support**: Support for both x86_64 and arm64 architectures on Linux

## Architecture

The extension follows Azure VM Extension standards with a handler-based architecture:

### Handler Framework
- **Lifecycle Operations**: Install, enable, disable, uninstall, and update operations
- **Platform-Specific Implementation**: Separate Linux (bash) and Windows (PowerShell) handlers
- **Azure Integration**: Native integration with Azure VM Extension framework
- **Status Reporting**: Structured JSON status updates to Azure portal

### Deployment Flow
1. **Azure invokes** the extension handler with configuration parameters
2. **Handler validates** the configuration and credentials
3. **CrowdStrike API** is called to download the appropriate sensor package
4. **Falcon installer** is executed to install and configure the sensor
5. **Status reporting** back to Azure portal with success/failure information

## Supported Platforms

> [!NOTE]
> For a complete list of supported platforms and versions, architectures, and compatibility, please refer to the CrowdStrike documentation.

### Supported Linux Distributions

See [https://falcon.crowdstrike.com/documentation/page/edd7717e/falcon-sensor-for-linux-system-requirements](https://falcon.crowdstrike.com/documentation/page/edd7717e/falcon-sensor-for-linux-system-requirements) for detailed support information and a complete list of:supported platforms:

- Ubuntu LTS
- Debian
- Red Hat Enterprise Linux
- SUSE Linux Enterprise Server

### Windows Versions

See [https://falcon.crowdstrike.com/documentation/page/ecc97e75/falcon-sensor-for-windows-deployment](https://falcon.crowdstrike.com/documentation/page/ecc97e75/falcon-sensor-for-windows-deployment) for detailed support information and a complete list of supported platforms:

- Windows Server
- Windows Desktop

## Falcon API Permissions

API clients are granted one or more API scopes. Scopes allow access to specific CrowdStrike APIs and describe the actions that an API client can perform.

Ensure the following API scopes are enabled:

> [!IMPORTANT]
> - **Sensor Download** [read]
> - **Sensor update policies** [read]
> - (optional) **Installation Tokens** [read]
>   > This scope allows the installer to retrieve a provisioning token from the API, but only if installation tokens are required in your environment.
> - (Optional) **Sensor update policies** [write]
>   > Required for reading the maintenance token during uninstall. This is only required for uninstall.

## Installation

The extension can be deployed through:
- **Azure Portal** - Individual VM deployment
- **Azure CLI** - Command-line deployment
- **Azure Resource Manager templates** - Infrastructure as Code
- **Azure Policy** - Enterprise-scale automated deployment (see [Policy Templates](policy/README.md))

## Usage

### Azure CLI

#### Linux
```bash
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name FalconSensorLinux \
  --publisher Crowdstrike.Falcon \
  --protected-settings '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET"
  }'
```

#### Windows
```bash
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name FalconSensorWindows \
  --publisher Crowdstrike.Falcon \
  --protected-settings '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET"
  }'
```

### Azure Portal
1. Navigate to your virtual machine in the Azure Portal
2. Select "Extensions + applications" from the left menu
3. Click "Add" and search for "CrowdStrike Falcon"
4. Select the appropriate extension (Linux or Windows)
5. Configure the required parameters and install

### Azure Policy

For automated enterprise-scale deployment using Azure Policy, see the [Policy Templates](policy/README.md) documentation for detailed instructions on deploying CrowdStrike Falcon at scale using Azure Policy. The templates support both subscription and management group level assignments, with automatic detection of Windows and Linux VMs.

## Documentation

- **[FAQ](docs/faq.md)** - Frequently asked questions and troubleshooting
- **[Testing Guide](tests/TESTING.md)** - Information about the testing framework
- **[Policy Templates](policy/README.md)** - Azure Policy deployment guide for enterprise-scale deployment

## Configuration

### Required Parameters
| Parameter | Description |
|-----------|-------------|
| `client_id` | CrowdStrike API Client ID |
| `client_secret` | CrowdStrike API Client Secret |

### Optional Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `cloud` | CrowdStrike cloud region (us-1, us-2, eu-1, us-gov-1) | Auto-detected |
| `tags` | Comma-separated list of sensor tags | None |
| `sensor_update_policy` | Sensor update policy name | platform_default |
| `provisioning_token` | Installation token (if required) | None |

### Windows-Specific Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `proxy_host` | HTTP proxy hostname | None |
| `proxy_port` | HTTP proxy port | None |
| `provisioning_wait_time` | Sensor provisioning timeout (ms) | 1200000 |

### Linux-Specific Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `proxy_host` | HTTP proxy hostname | None |
| `proxy_port` | HTTP proxy port | None |

## Frequently Asked Questions (FAQs)

Have additional questions about the extension? Check out our [FAQ documentation](docs/faq.md) for more information. If your question is not answered in the FAQ doc, feel free to [open a discussion](https://github.com/CrowdStrike/azure-vm-extension/discussions) in our GitHub repository.

## Contributing

We welcome contributions that improve the installation and distribution processes of the Falcon Sensor. Please ensure that your contributions align with our coding standards and pass all CI/CD checks.

## Support

The CrowdStrike Azure VM Extension is a community-driven, open source project designed to streamline the deployment and use of the CrowdStrike Falcon sensor. While not a formal CrowdStrike product, Falcon Installer is maintained by CrowdStrike and supported in partnership with the open source developer community.

For additional support, please see the [SUPPORT.md](SUPPORT.md) file.

## License

See [LICENSE](LICENSE)
