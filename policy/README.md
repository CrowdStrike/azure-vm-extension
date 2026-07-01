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
- **Automatic Detection**: Policies detect Windows and Linux VMs, Virtual Machine Scale Sets (VMSS), and Azure Arc-connected servers automatically
- **Extension Installation**: Uses official CrowdStrike VM extensions for reliable deployment
- **VM, VMSS, and Arc Support**: Comprehensive coverage of individual VMs, VMSS instances, and Arc-connected servers
- **Managed Identity**: Secure deployment using system-assigned managed identities
- **Role Assignment**: Automatically assigns necessary permissions for VM, VMSS, and Arc extension deployment

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
- **Sensor Update Policy**: Configure to match your organization's desired sensor update policy instead of using the pre-defined default
- **Tags**: Sensor grouping and organization
- **Proxy Settings**: HTTP proxy configuration
- **Platform-specific settings**: Windows PAC URL, VDI mode; Linux provisioning token

## Policy Structure

Each template creates up to **6 policy definitions** for comprehensive coverage:

1. **Linux VM Policy** - Deploys Falcon sensor on individual Linux virtual machines
2. **Linux VMSS Policy** - Deploys Falcon sensor on Linux Virtual Machine Scale Sets
3. **Windows VM Policy** - Deploys Falcon sensor on individual Windows virtual machines
4. **Windows VMSS Policy** - Deploys Falcon sensor on Windows Virtual Machine Scale Sets
5. **Linux Arc Policy** - Deploys Falcon sensor on Linux Azure Arc-connected servers
6. **Windows Arc Policy** - Deploys Falcon sensor on Windows Azure Arc-connected servers

The Azure Arc policies are controlled by the `deployToArc` parameter (default: `true`). Set `deployToArc=false` to skip Arc policy creation if you only need coverage for Azure-native VMs and VMSS.

All policies support the same configuration parameters and authentication methods, ensuring consistent sensor deployment across your entire Azure and hybrid compute infrastructure.

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

> [!IMPORTANT]
> As a best practice, make sure to change the `sensorUpdatePolicy` from the default to match your organization's desired sensor update policy as this determins what sensor version will be installed!

### Common Parameters
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `clientId` | string | OAuth2 Client ID | '' |
| `clientSecret` | securestring | OAuth2 Client Secret | '' |
| `accessToken` | securestring | API Access Token | '' |
| `azureVaultName` | string | Azure Key Vault name containing CrowdStrike credentials | '' |
| `azureManagedIdentityClientId` | string | Azure Managed Identity Client ID for Key Vault access (required when `azureManagedIdentityResourceId` is set) | '' |
| `azureManagedIdentityResourceId` | string | Full ARM resource ID of the user-assigned managed identity to attach to VMs/VMSS for Key Vault access (requires `azureManagedIdentityClientId`) | '' |
| `cloud` | string | Falcon Cloud (e.g. us-1, us-2, eu-1, us-gov-1) | 'autodiscover' |
| `memberCid` | string | Member CID for MSSP. Requires Parent API Credentials and the Child CID for memberCid.| '' |
| `sensorUpdatePolicy` | string | Sensor update policy name. Configure this to match your organization's desired sensor update policy instead of using the pre-defined default. | 'platform_default' |
| `tags` | string | Comma-separated sensor tags | '' |
| `policyEffect` | string | Policy effect | 'DeployIfNotExists' |
| `createRoleAssignments` | bool | Create role assignments for managed identities | true |
| `deployToArc` | bool | Deploy policies for Azure Arc-connected servers | true |
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

> [!NOTE]
> **Azure Arc limitation:** Azure Arc-connected servers only support system-assigned managed identities. The `azureManagedIdentityClientId` parameter is not used for Arc policy definitions and will be ignored on Arc servers. On Arc, the extension authenticates to Key Vault using the machine's system-assigned managed identity via the HIMDS challenge/response flow automatically.

### Automatic Identity Attachment for VMs and VMSS

When using Key Vault authentication with a user-assigned managed identity, the identity must be attached to the VM or VMSS before the extension can use it. The policy templates support automatic identity attachment via the `azureManagedIdentityResourceId` parameter.

When `azureManagedIdentityResourceId` is provided:
1. The policy deployment attaches the specified user-assigned identity to the VM or VMSS
2. The extension then deploys with a `dependsOn` on the identity attachment, ensuring correct ordering
3. The identity type is safely preserved — existing `SystemAssigned` identities are not removed

**Example — Key Vault authentication with automatic identity attachment:**
```bash
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    azureVaultName="my-crowdstrike-vault" \
    azureManagedIdentityClientId="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" \
    azureManagedIdentityResourceId="/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/crowdstrike-keyvault-identity"
```

> [!NOTE]
> - The user-assigned managed identity resource must already exist before deploying the policy
> - The identity must have appropriate Key Vault access (e.g., Key Vault Secrets User RBAC role or a Key Vault access policy)
> - When `azureManagedIdentityResourceId` is provided, the policy assignment identity additionally requires the **Managed Identity Operator** role. With `createRoleAssignments=true` (default), this is created automatically at subscription scope. With `createRoleAssignments=false`, you must manually assign this role — either at subscription scope or scoped to the identity resource itself (see [Manual Role Assignment](#manual-role-assignment))
> - This feature applies to VMs and VMSS (not Arc)

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

The templates create managed identities that need **Virtual Machine Contributor** role to deploy VM and VMSS extensions, and **Azure Connected Machine Resource Administrator** role for Arc-connected server extensions. When using `azureManagedIdentityResourceId` for automatic identity attachment, the **Managed Identity Operator** role is also required.

> [!NOTE]
> The **Virtual Machine Contributor** role provides sufficient permissions for both individual VM extensions (`Microsoft.Compute/virtualMachines/extensions/*`) and VMSS extensions (`Microsoft.Compute/virtualMachineScaleSets/extensions/*`). The **Azure Connected Machine Resource Administrator** role provides permissions for Arc extensions (`Microsoft.HybridCompute/machines/extensions/*`). No additional role assignments are required.

**If you have Owner or User Access Administrator role:**
- By default, `createRoleAssignments=true` will create the necessary role assignments automatically. You do not need to take any additional action.

**If you lack role assignment permissions:**
- Set `createRoleAssignments=false`
- Manually create role assignments after deployment

### Manual Role Assignment

When `createRoleAssignments=false`, you must manually assign the VM Contributor role to the VM/VMSS policy managed identities and the Azure Connected Machine Resource Administrator role to the Arc policy managed identities:

#### Azure CLI
```bash
# Set deployment name
DEPLOYMENT_NAME="YourDeploymentName"

# Get all policy assignment principal IDs from deployment outputs
LINUX_VM_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.linuxVmPolicyPrincipalId.value' -o tsv)
LINUX_VMSS_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.linuxVmssPolicyPrincipalId.value' -o tsv)
WINDOWS_VM_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.windowsVmPolicyPrincipalId.value' -o tsv)
WINDOWS_VMSS_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.windowsVmssPolicyPrincipalId.value' -o tsv)

# Assign VM Contributor role to all policy managed identities
SUBSCRIPTION_SCOPE="/subscriptions/$(az account show --query id -o tsv)"

az role assignment create --assignee "$LINUX_VM_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$LINUX_VMSS_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$WINDOWS_VM_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$WINDOWS_VMSS_PRINCIPAL_ID" --role "Virtual Machine Contributor" --scope "$SUBSCRIPTION_SCOPE"

# If deployToArc=true, also assign Arc role
LINUX_ARC_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.linuxArcPolicyPrincipalId.value' -o tsv)
WINDOWS_ARC_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.windowsArcPolicyPrincipalId.value' -o tsv)

az role assignment create --assignee "$LINUX_ARC_PRINCIPAL_ID" --role "Azure Connected Machine Resource Administrator" --scope "$SUBSCRIPTION_SCOPE"
az role assignment create --assignee "$WINDOWS_ARC_PRINCIPAL_ID" --role "Azure Connected Machine Resource Administrator" --scope "$SUBSCRIPTION_SCOPE"

# If azureManagedIdentityResourceId is provided, also assign Managed Identity Operator role
# This can be scoped to the subscription or narrowly to the identity resource itself
IDENTITY_RESOURCE_ID="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>"

az role assignment create --assignee "$LINUX_VM_PRINCIPAL_ID" --role "Managed Identity Operator" --scope "$IDENTITY_RESOURCE_ID"
az role assignment create --assignee "$WINDOWS_VM_PRINCIPAL_ID" --role "Managed Identity Operator" --scope "$IDENTITY_RESOURCE_ID"
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

# If deployToArc=true, also assign Arc role
$linuxArcPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.linuxArcPolicyPrincipalId.Value
$windowsArcPrincipalId = (Get-AzSubscriptionDeployment -Name $deploymentName).Outputs.windowsArcPolicyPrincipalId.Value

New-AzRoleAssignment -ObjectId $linuxArcPrincipalId -RoleDefinitionName "Azure Connected Machine Resource Administrator" -Scope $subscriptionScope
New-AzRoleAssignment -ObjectId $windowsArcPrincipalId -RoleDefinitionName "Azure Connected Machine Resource Administrator" -Scope $subscriptionScope

# If azureManagedIdentityResourceId is provided, also assign Managed Identity Operator role
# This can be scoped to the subscription or narrowly to the identity resource itself
$identityResourceId = "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>"

New-AzRoleAssignment -ObjectId $linuxVmPrincipalId -RoleDefinitionName "Managed Identity Operator" -Scope $identityResourceId
New-AzRoleAssignment -ObjectId $windowsVmPrincipalId -RoleDefinitionName "Managed Identity Operator" -Scope $identityResourceId
```
