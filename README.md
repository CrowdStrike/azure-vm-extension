# CrowdStrike Azure VM Extension

This repository contains the CrowdStrike Azure VM Extension, which enables automated deployment and management of the CrowdStrike Falcon sensor on Azure virtual machines.

## Overview

The CrowdStrike Azure VM Extension allows you to:
- Deploy the Falcon sensor to Azure VMs at scale
- Manage sensor configuration and updates
- Integrate CrowdStrike protection into your Azure infrastructure

## Requirements

- Azure subscription
- CrowdStrike Falcon subscription
- CrowdStrike API credentials (Client ID and Secret)

## Installation

The extension can be deployed through:
- Azure Portal
- Azure CLI
- Azure Resource Manager templates

## Usage

Basic deployment example:

```bash
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name CrowdStrikeLinuxAgent \
  --publisher CrowdStrike \
  --protected-settings '{"client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET"}'
```

## Configuration

The extension supports the following configuration parameters:

- `client_id`: Your CrowdStrike API Client ID
- `client_secret`: Your CrowdStrike API Client Secret
- Additional parameters for advanced configuration

## Contributing

We welcome contributions that improve the installation and distribution processes of the Falcon Sensor. Please ensure that your contributions align with our coding standards and pass all CI/CD checks.

## Support

Falcon Installer is a community-driven, open source project designed to streamline the deployment and use of the CrowdStrike Falcon sensor. While not a formal CrowdStrike product, Falcon Installer is maintained by CrowdStrike and supported in partnership with the open source developer community.

For additional support, please see the [SUPPORT.md](SUPPORT.md) file.

## License

See [LICENSE](LICENSE)
