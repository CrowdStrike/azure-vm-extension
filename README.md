# CrowdStrike Azure VM Extension

The CrowdStrike Azure VM Extension is an open-source solution that simplifies and automates the installation of the CrowdStrike Falcon sensor on Azure virtual machines.

## Overview

The CrowdStrike Azure VM Extension allows you to:
- Deploy the Falcon sensor to Azure VMs at scale
- Manage sensor configuration and updates
- Integrate CrowdStrike protection into your Azure infrastructure

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
- Azure Portal
- Azure CLI
- Azure Resource Manager templates

## Usage

Basic deployment examples

### Linux

```shell
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name FalconSensorLinux \
  --publisher Crowdstrike.Falcon \
  --protected-settings '{"client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET"}'
```

### Windows

```shell
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name FalconSensorWindows \
  --publisher Crowdstrike.Falcon \
  --protected-settings '{"client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET"}'
```

## Configuration

The extension supports the following configuration parameters:

- `client_id`: Your CrowdStrike API Client ID
- `client_secret`: Your CrowdStrike API Client Secret
- Additional parameters for advanced configuration

## Frequently Asked Questions (FAQs)

Have additional questions about the extension? Check out our [FAQ documentation](docs/faq.md) for more information. If your question is not answered in the FAQ doc, feel free to [open a discussion](https://github.com/CrowdStrike/azure-vm-extension/discussions) in our GitHub repository.

## Contributing

We welcome contributions that improve the installation and distribution processes of the Falcon Sensor. Please ensure that your contributions align with our coding standards and pass all CI/CD checks.

## Support

Falcon Installer is a community-driven, open source project designed to streamline the deployment and use of the CrowdStrike Falcon sensor. While not a formal CrowdStrike product, Falcon Installer is maintained by CrowdStrike and supported in partnership with the open source developer community.

For additional support, please see the [SUPPORT.md](SUPPORT.md) file.

## License

See [LICENSE](LICENSE)
