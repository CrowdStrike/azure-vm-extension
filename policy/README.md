# CrowdStrike Falcon Azure Policy Templates

This folder contains Azure Policy templates for automated deployment of CrowdStrike Falcon sensors using the official CrowdStrike VM extensions at scale.

## Contents

### Policy Templates
- **`falcon-subscription.bicep`** - Creates policy definitions and assignments at subscription level
- **`falcon-managementgroup.bicep`** - Creates policy assignments at management group level

## Getting the Policy Templates

### Download from GitHub Releases

The Azure Policy templates are available as part of the official CrowdStrike Azure VM Extension releases:

1. **Download Latest Release**: Download the latest release zip file containing the [Azure Policy Bicep templates](https://github.com/CrowdStrike/azure-vm-extension/releases/latest/download/csfalcon-azure-policy-bicep.zip)

2. **Extract Policy Files**: Extract the zip file which contains:
   - `falcon-subscription.bicep` - Subscription-level policy template
   - `falcon-managementgroup.bicep` - Management group-level policy template
   - `README.md` - This documentation

3. **Use Templates**: Use the extracted `.bicep` files with Azure CLI or PowerShell as shown in the deployment examples below

## Features

### Core Functionality
- **Automatic Detection**: Policies detect Windows and Linux VMs automatically
- **Extension Installation**: Uses official CrowdStrike VM extensions for reliable deployment
- **Managed Identity**: Secure deployment using system-assigned managed identities
- **Role Assignment**: Automatically assigns necessary permissions for VM extension deployment

### Policy Effects
- **DeployIfNotExists**: Automatically installs Falcon sensor if not present (default)
- **AuditIfNotExists**: Reports VMs without Falcon sensor but doesn't install
- **Disabled**: Disables the policy

### Authentication Methods
- **OAuth2 Client Credentials**: Recommended method using Client ID and Secret
- **Access Token**: Direct API token authentication

### Configuration Options
- **Falcon Cloud**: Auto-discover, US-1, US-2, EU-1, US-GOV-1
- **Member CID**: For MSSP scenarios
- **Sensor Update Policy**: Control sensor update behavior
- **Tags**: Sensor grouping and organization
- **Proxy Settings**: HTTP proxy configuration
- **Platform-specific settings**: Windows PAC URL, VDI mode; Linux provisioning token

## Deployment Options

### Option 1: Subscription Level (Recommended)

Deploy policies at the subscription level to cover all VMs in the subscription:

#### Azure CLI
```bash
# Deploy both Linux and Windows policies
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret"

# Deploy only Linux policy
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    operatingSystem="linux" \
    clientId="your-client-id" \
    clientSecret="your-client-secret" \
    cloud="gov1"

# Deploy only Windows policy
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    operatingSystem="windows" \
    clientId="your-client-id" \
    clientSecret="your-client-secret"
```

#### PowerShell
```powershell
# Deploy both Linux and Windows policies
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"

# Deploy only Linux policy
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -operatingSystem "linux" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret" `
  -cloud "gov1"

# Deploy only Windows policy
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -operatingSystem "windows" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"
```

### Option 2: Management Group Level

Deploy policy assignments at the management group level for enterprise-wide deployment.

> [!IMPORTANT]
> Requires existing policy definitions from subscription level deployment first.

#### Azure CLI
```bash
# First, deploy subscription-level policies to create policy definitions
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret"

# Then deploy management group assignments
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret"
```

#### PowerShell
```powershell
# First, deploy subscription-level policies to create policy definitions
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"

# Then deploy management group assignments
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"
```

## Prerequisites

### CrowdStrike API Credentials

See https://github.com/CrowdStrike/azure-vm-extension?tab=readme-ov-file#falcon-api-permissions for specific Falcon API permissions required for deployment.

### Azure Permissions
- `Microsoft.Authorization/policyDefinitions/write`
- `Microsoft.Authorization/policyAssignments/write`
- `Microsoft.Authorization/roleAssignments/write`
- `Microsoft.Compute/virtualMachines/extensions/write`

## Parameters Reference

### Common Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `clientId` | string | OAuth2 Client ID | '' |
| `clientSecret` | securestring | OAuth2 Client Secret | '' |
| `accessToken` | securestring | API Access Token | '' |
| `cloud` | string | Falcon Cloud (us-1, us-2, eu-1, us-gov-1) | 'autodiscover' |
| `memberCid` | string | Member CID for MSSP | '' |
| `sensorUpdatePolicy` | string | Sensor update policy name | 'platform_default' |
| `tags` | string | Comma-separated sensor tags | '' |
| `policyEffect` | string | Policy effect | 'DeployIfNotExists' |
| `createRoleAssignments` | bool | Create role assignments for managed identities | true |

### Windows-Specific Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `pacUrl` | string | Proxy auto-configuration URL | '' |
| `provisioningWaitTime` | string | Provisioning timeout (ms) | '1200000' |
| `vdi` | bool | Enable VDI mode | false |
| `disableProvisioningWait` | bool | Disable provisioning wait | false |
| `disableStart` | bool | Disable automatic start | false |

### Linux-Specific Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `provisioningToken` | securestring | Provisioning token | '' |
| `disableProxy` | bool | Disable proxy settings | false |

## Role Assignment Configuration

### Understanding `createRoleAssignments` Parameter

The templates create managed identities that need **Virtual Machine Contributor** role to deploy VM extensions.

**If you have Owner or User Access Administrator role:**
- Use default `createRoleAssignments=true`
- Role assignments created automatically

**If you lack role assignment permissions:**
- Set `createRoleAssignments=false`
- Manually create role assignments after deployment

### Manual Role Assignment

When `createRoleAssignments=false`, you must manually assign the VM Contributor role:

#### Azure CLI
```bash
# Get policy assignment principal IDs from deployment outputs
LINUX_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.linuxPolicyPrincipalId.value' -o tsv)
WINDOWS_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.windowsPolicyPrincipalId.value' -o tsv)

# Assign VM Contributor role to managed identities
az role assignment create \
  --assignee "$LINUX_PRINCIPAL_ID" \
  --role "Virtual Machine Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)"

az role assignment create \
  --assignee "$WINDOWS_PRINCIPAL_ID" \
  --role "Virtual Machine Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)"
```

#### PowerShell
```powershell
# Get policy assignment principal IDs from deployment outputs
$deploymentName = "YourDeploymentName"
$linuxPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.linuxPolicyPrincipalId.Value
$windowsPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.windowsPolicyPrincipalId.Value

# Assign VM Contributor role to managed identities
New-AzRoleAssignment `
  -ObjectId $linuxPrincipalId `
  -RoleDefinitionName "Virtual Machine Contributor" `
  -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)"

New-AzRoleAssignment `
  -ObjectId $windowsPrincipalId `
  -RoleDefinitionName "Virtual Machine Contributor" `
  -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)"
```
