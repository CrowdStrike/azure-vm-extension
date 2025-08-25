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

See [https://falcon.crowdstrike.com/documentation/page/edd7717e/falcon-sensor-for-linux-system-requirements](https://falcon.crowdstrike.com/documentation/page/edd7717e/falcon-sensor-for-linux-system-requirements) for detailed support information and a complete list of supported platforms:

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
- **Azure CLI** - Command-line deployment
- **Azure Resource Manager templates** - Infrastructure as Code
- **Azure Policy** - Enterprise-scale automated deployment (see [Policy Templates](policy/README.md))

## Configuration

The CrowdStrike Azure VM Extension uses two types of configuration parameters:

- **Settings**: Non-sensitive configuration parameters passed as plain text
- **Protected Settings**: Sensitive parameters (credentials, tokens) that are encrypted in transit and at rest

> [!IMPORTANT]
> Always place sensitive information like credentials and tokens in `protectedSettings` to ensure they are encrypted and secure.

### Protected Settings (Sensitive Parameters)

These parameters contain sensitive information and **must** be placed in the `protectedSettings` section:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `client_id` | CrowdStrike API Client ID | Yes* |
| `client_secret` | CrowdStrike API Client Secret | Yes* |
| `access_token` | CrowdStrike API Access Token (alternative to client_id/client_secret) | Yes* |
| `provisioning_token` | Installation token (if required by your environment) | No |

*Either `client_id`/`client_secret` or `access_token` is required for authentication.

### Settings (Non-Sensitive Parameters)

These configuration parameters can be placed in the `settings` section:

#### Common Settings (Linux and Windows)
| Parameter | Description | Default |
|-----------|-------------|---------|
| `cloud` | CrowdStrike cloud region (us-1, us-2, eu-1, us-gov-1, autodiscover) | autodiscover |
| `member_cid` | Member CID for MSSP scenarios | None |
| `sensor_update_policy` | Sensor update policy name | platform_default |
| `tags` | Comma-separated list of sensor tags | None |
| `disable_proxy` | Disable proxy settings | false |
| `proxy_host` | HTTP proxy hostname | None |
| `proxy_port` | HTTP proxy port | None |

#### Windows-Specific Settings
| Parameter | Description | Default |
|-----------|-------------|---------|
| `pac_url` | Proxy auto-configuration URL | None |
| `disable_provisioning_wait` | Disable provisioning wait timeout | false |
| `disable_start` | Prevent sensor from starting until reboot | false |
| `provisioning_wait_time` | Provisioning timeout in milliseconds | 1200000 |
| `vdi` | Enable virtual desktop infrastructure mode | false |

## Usage

### Azure CLI

#### Linux
```bash
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name FalconSensorLinux \
  --publisher Crowdstrike.Falcon \
  --settings '{
    "cloud": "autodiscover",
    "tags": "azure,production"
  }' \
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
  --settings '{
    "cloud": "autodiscover",
    "tags": "azure,production"
  }' \
  --protected-settings '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET"
  }'
```

### Using Azure Key Vault with ARM Templates

For enhanced security, store sensitive CrowdStrike API credentials in Azure Key Vault rather than directly in ARM templates. This ensures credentials are encrypted, access-controlled, and auditable.

#### Azure Vault Setup

Follow the [Azure Key Vault documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/key-vault-parameter) to create a Key Vault and store your CrowdStrike API credentials as secrets.

#### ARM Template Integration

Store your CrowdStrike API credentials in Key Vault as secrets. You can use any secret names you prefer - the examples below use:
- `FalconClientId` - Your CrowdStrike API Client ID
- `FalconClientSecret` - Your CrowdStrike API Client Secret

##### Example Using Key Vault References in an ARM template

Example of parameters file with Key Vault references:
```json
{
    "parameters": {
        "falconClientId": {
            "reference": {
                "keyVault": {
                    "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}"
                },
                "secretName": "FalconClientId"
            }
        },
        "falconClientSecret": {
            "reference": {
                "keyVault": {
                    "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}"
                },
                "secretName": "FalconClientSecret"
            }
        }
    }
}
```

Example of ARM template deployment with inline parameters:
```json
{
    "type": "Microsoft.Compute/virtualMachines/extensions",
    "apiVersion": "2021-07-01",
    "name": "[concat(parameters('vmName'), '/', variables('extensionName'))]",
    "location": "[parameters('location')]",
    "dependsOn": [
        "[resourceId('Microsoft.Compute/virtualMachines', parameters('vmName'))]"
    ],
    "properties": {
        "publisher": "[variables('extensionPublisher')]",
        "type": "[variables('extensionType')]",
        "typeHandlerVersion": "[variables('extensionTypeHandlerVersion')]",
        "autoUpgradeMinorVersion": true,
        "protectedSettings": {
            "client_id": "[parameters('falconClientId')]",
            "client_secret": "[parameters('falconClientSecret')]"
        }
    }
}
```

The deployment identity must have `Get` permissions on the Key Vault secrets for the deployment to succeed.

### Azure Policy

For automated enterprise-scale deployment using Azure Policy, see the [Policy Templates](policy/README.md) documentation for detailed instructions on deploying CrowdStrike Falcon at scale using Azure Policy. The templates support both subscription and management group level assignments, with automatic detection of Windows and Linux VMs.

## Documentation

- **[FAQ](docs/faq.md)** - Frequently asked questions and troubleshooting
- **[Testing Guide](tests/TESTING.md)** - Information about the testing framework
- **[Policy Templates](policy/README.md)** - Azure Policy deployment guide for enterprise-scale deployment

## Troubleshooting

If you encounter any issues during the extension deployment process, the following logs will be generated on the VMs:

- **`cshandler.log`**: This log file captures the standard output and error information from the extension handler operations (install, enable, disable, uninstall, update).
- **`CommandExecution.log`**: This log file contains detailed information about command execution during the extension operations.
- **`falcon-installer.log`**: This log file contains detailed information about the Falcon sensor installation process. It includes messages about the progress of the installation, any errors encountered, and other relevant details.

These logs can be found under `/var/log/azure/Crowdstrike.Falcon.FalconSensorLinux/` for Linux VMs and `C:\WindowsAzure\Logs\Plugins\Crowdstrike.Falcon.FalconSensorWindows\<version>\` for Windows VMs.

The extension handler working directory (which includes downloaded installer files, configuration, and status files) can be found under `/var/lib/waagent/Crowdstrike.Falcon.FalconSensorLinux-<version>/` for Linux VMs and `C:\Packages\Plugins\Crowdstrike.Falcon.FalconSensorWindows\<version>\` for Windows VMs.

In addition to the VM logs, you can also check the extension status and configuration through the Azure portal or Azure CLI:

- Check extension status in Azure portal under VM → Extensions + applications
- Use Azure CLI: `az vm extension show --resource-group <rg> --vm-name <vm> --name FalconSensorLinux` (or `FalconSensorWindows`)

Review these logs for failures as to why the installation and deployment failed. When contacting CrowdStrike support or creating a GitHub issue, these logs should be provided.

> [!IMPORTANT]
> When providing logs, please make sure to sanitize the output and do not provide any credentials or sensitive information.

## Contributing

We welcome contributions that improve the installation and distribution processes of the Falcon Sensor. Please ensure that your contributions align with our coding standards and pass all CI/CD checks.

## Support

The CrowdStrike Azure VM Extension is a community-driven, open source project designed to streamline the deployment and use of the CrowdStrike Falcon sensor. While not a formal CrowdStrike product, Falcon Installer is maintained by CrowdStrike and supported in partnership with the open source developer community.

For additional support, please see the [SUPPORT.md](SUPPORT.md) file.

## License

See [LICENSE](LICENSE)
