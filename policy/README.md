# CrowdStrike Falcon Azure Policy Templates

This folder contains Azure Policy templates for automated deployment of CrowdStrike Falcon sensors using the official CrowdStrike VM extensions at scale.

## Contents

### Policy Templates
- **`falcon-subscription.bicep`** - Creates policy definitions and assignments at subscription level
- **`falcon-managementgroup.bicep`** - Creates policy definitions and assignments at management group level

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
- **Automatic Detection**: Policies detect Windows and Linux VMs and Virtual Machine Scale Sets (VMSS) automatically
- **Extension Installation**: Uses official CrowdStrike VM extensions for reliable deployment
- **VM and VMSS Support**: Comprehensive coverage of both individual VMs and VMSS instances
- **Managed Identity**: Secure deployment using system-assigned managed identities
- **Role Assignment**: Automatically assigns necessary permissions for VM and VMSS extension deployment

### Policy Effects
- **DeployIfNotExists**: Automatically installs Falcon sensor if not present (default)
- **AuditIfNotExists**: Reports VMs without Falcon sensor but doesn't install
- **Disabled**: Disables the policy

### Authentication Methods
- **OAuth2 Client Credentials**: Recommended method using Client ID and Secret
- **Access Token**: Direct API token authentication
- **Azure Key Vault**: Secure credential storage using Azure Key Vault integration

### Configuration Options
- **Falcon Cloud**: Auto-discover, US-1, US-2, EU-1, US-GOV-1
- **Member CID**: For MSSP scenarios
- **Sensor Update Policy**: Control sensor update behavior
- **Tags**: Sensor grouping and organization
- **Proxy Settings**: HTTP proxy configuration
- **Platform-specific settings**: Windows PAC URL, VDI mode; Linux provisioning token

## Policy Structure

Each template creates **4 policy definitions** for comprehensive coverage:

1. **Linux VM Policy** - Deploys Falcon sensor on individual Linux virtual machines
2. **Linux VMSS Policy** - Deploys Falcon sensor on Linux Virtual Machine Scale Sets
3. **Windows VM Policy** - Deploys Falcon sensor on individual Windows virtual machines
4. **Windows VMSS Policy** - Deploys Falcon sensor on Windows Virtual Machine Scale Sets

All policies support the same configuration parameters and authentication methods, ensuring consistent sensor deployment across your entire Azure compute infrastructure.

## Deployment Options

### Option 1: Subscription Level (Recommended)

Deploy policies at the subscription level to cover all VMs and VMSS in the subscription:

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

Deploy policies at the management group level for enterprise-wide deployment across multiple subscriptions covering all VMs and VMSS.

> [!IMPORTANT]
> The management group must already exist before deploying policies to it. Use `az account management-group create` to create a new management group if needed.

#### Creating a Management Group (Optional)
If you need to create a new management group first:

```bash
# Create a new management group
az account management-group create \
  --name "my-management-group" \
  --display-name "My CrowdStrike Management Group"
```

#### Azure CLI
```bash
# Deploy both Linux and Windows policies at management group level
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret"

# Deploy only Linux policy at management group level
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    operatingSystem="linux" \
    clientId="your-client-id" \
    clientSecret="your-client-secret" \
    cloud="gov1"

# Deploy only Windows policy at management group level
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    operatingSystem="windows" \
    clientId="your-client-id" \
    clientSecret="your-client-secret"
```

#### PowerShell
```powershell
# Deploy both Linux and Windows policies at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"

# Deploy only Linux policy at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -operatingSystem "linux" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret" `
  -cloud "gov1"

# Deploy only Windows policy at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -operatingSystem "windows" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret"
```

## Prerequisites

### CrowdStrike API Credentials

See https://github.com/CrowdStrike/azure-vm-extension?tab=readme-ov-file#falcon-api-permissions for specific Falcon API permissions required for deployment.

### Azure Permissions

**Recommended Azure Built-in Roles:**
- **User Access Administrator** (for role assignments, if `createRoleAssignments=true`)

> [!WARNING]
> Management group deployments require elevated permissions compared to subscription deployments. Ensure your account has the appropriate roles assigned at the management group level before attempting deployment.

#### For Subscription-Level Deployment
- `Microsoft.Authorization/policyDefinitions/write`
- `Microsoft.Authorization/policyAssignments/write`
- `Microsoft.Authorization/roleAssignments/write`
- `Microsoft.Compute/virtualMachines/extensions/write`

#### For Management Group-Level Deployment
- `Microsoft.Authorization/policyDefinitions/write` (at management group scope)
- `Microsoft.Authorization/policyAssignments/write` (at management group scope)
- `Microsoft.Authorization/roleAssignments/write` (at management group scope)
- `Microsoft.Resources/deployments/validate/action` (at management group scope)
- `Microsoft.Resources/deployments/write` (at management group scope)
- `Microsoft.Compute/virtualMachines/extensions/write` (inherited by subscriptions)

## Parameters Reference

### Common Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `clientId` | string | OAuth2 Client ID | '' |
| `clientSecret` | securestring | OAuth2 Client Secret | '' |
| `accessToken` | securestring | API Access Token | '' |
| `azureVaultName` | string | Azure Key Vault name containing CrowdStrike credentials | '' |
| `azureManagedIdentityClientId` | string | Azure Managed Identity Client ID for Key Vault access | '' |
| `cloud` | string | Falcon Cloud (us-1, us-2, eu-1, us-gov-1) | 'autodiscover' |
| `memberCid` | string | Member CID for MSSP | '' |
| `sensorUpdatePolicy` | string | Sensor update policy name | 'platform_default' |
| `tags` | string | Comma-separated sensor tags | '' |
| `policyEffect` | string | Policy effect | 'DeployIfNotExists' |
| `createRoleAssignments` | bool | Create role assignments for managed identities | true |
| `proxySettings` | object | Network proxy configuration settings | `{proxyHost: '', proxyPort: ''}` |
| `extensionSettings` | object | Extension configuration settings | `{handlerVersion: 'Latest release version', autoUpgradeMinorVersion: true}` |

### Object Parameter Details

#### `proxySettings` Object
| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `proxyHost` | string | HTTP proxy host | '' |
| `proxyPort` | string | HTTP proxy port | '' |

#### `extensionSettings` Object
| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `handlerVersion` | string | Extension handler version (automatically updated with releases) | Latest release version |
| `autoUpgradeMinorVersion` | bool | Enable automatic minor version upgrades | true |

> [!IMPORTANT]
> When specifying the Azure vault with `azure_vault_name`, make sure that all VMs have the appropriate permissions to list and get the Key Vault secrets.
> The extension will fail to install if the VM doesn't have the required permissions to access the secrets.
> Any secrets in the vault should be prefixed with `FALCON-` e.g. FALCON-CLIENT-ID, FALCON-CLIENT-SECRET, FALCON-ACCESS-TOKEN, etc.
>
> When using `azure_vault_name` with `azure_managed_identity_client_id`, the extension will use the specified user-assigned managed identity to authenticate with the Key Vault instead of the VM's system-assigned managed identity. This provides more granular control over Key Vault access permissions and is useful in scenarios where you want to use a specific managed identity for Key Vault authentication.

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

The templates create managed identities that need **Virtual Machine Contributor** role to deploy both VM and VMSS extensions.

> [!NOTE]
> The **Virtual Machine Contributor** role provides sufficient permissions for both individual VM extensions (`Microsoft.Compute/virtualMachines/extensions/*`) and VMSS extensions (`Microsoft.Compute/virtualMachineScaleSets/extensions/*`). No additional role assignments are required for VMSS support.

**If you have Owner or User Access Administrator role:**
- By default, `createRoleAssignments=true` will create the necessary role assignments automatically. You do not need to take any additional action.

**If you lack role assignment permissions:**
- Set `createRoleAssignments=false`
- Manually create role assignments after deployment

### Manual Role Assignment

When `createRoleAssignments=false`, you must manually assign the VM Contributor role to all 4 policy managed identities:

#### Azure CLI
```bash
# Get all policy assignment principal IDs from deployment outputs
LINUX_VM_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.linuxVmPolicyPrincipalId.value' -o tsv)
LINUX_VMSS_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.linuxVmssPolicyPrincipalId.value' -o tsv)
WINDOWS_VM_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.windowsVmPolicyPrincipalId.value' -o tsv)
WINDOWS_VMSS_PRINCIPAL_ID=$(az deployment sub show --name YourDeploymentName --query 'properties.outputs.windowsVmssPolicyPrincipalId.value' -o tsv)

# Assign VM Contributor role to all policy managed identities
SUBSCRIPTION_SCOPE="/subscriptions/$(az account show --query id -o tsv)"

az role assignment create --assignee "$LINUX_VM_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$LINUX_VMSS_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$WINDOWS_VM_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$WINDOWS_VMSS_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
```

#### PowerShell
```powershell
# Get all policy assignment principal IDs from deployment outputs
$deploymentName = "YourDeploymentName"
$linuxVmPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.linuxVmPolicyPrincipalId.Value
$linuxVmssPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.linuxVmssPolicyPrincipalId.Value
$windowsVmPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.windowsVmPolicyPrincipalId.Value
$windowsVmssPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.windowsVmssPolicyPrincipalId.Value

# Assign VM Contributor role to all policy managed identities
$subscriptionScope = "/subscriptions/$((Get-AzContext).Subscription.Id)"

New-AzRoleAssignment -ObjectId $linuxVmPrincipalId -RoleDefinitionName "Virtual Machine Contributor" -Scope $subscriptionScope
New-AzRoleAssignment -ObjectId $linuxVmssPrincipalId -RoleDefinitionName "Virtual Machine Contributor" -Scope $subscriptionScope
New-AzRoleAssignment -ObjectId $windowsVmPrincipalId -RoleDefinitionName "Virtual Machine Contributor" -Scope $subscriptionScope
New-AzRoleAssignment -ObjectId $windowsVmssPrincipalId -RoleDefinitionName "Virtual Machine Contributor" -Scope $subscriptionScope
```
