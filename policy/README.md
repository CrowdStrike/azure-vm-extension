# CrowdStrike Falcon Azure Policy Templates

This folder contains Azure Policy templates for automated deployment of CrowdStrike Falcon sensors using the official CrowdStrike VM extensions at scale.

## Contents

### Policy Templates
- **`falcon-subscription.bicep`** - Creates policy definitions and assignments at subscription level
- **`falcon-managementgroup.bicep`** - Creates policy definitions and assignments at management group level
- **`keyvault-deploy-access.bicep`** - Module used by both templates to grant Key Vault access; keep it in the same folder

## Getting the Policy Templates

### Download from GitHub Releases

The Azure Policy templates are available as part of the official CrowdStrike Azure VM Extension releases:

1. **Download Latest Release**: Download the latest release zip file containing the [Azure Policy Bicep templates](https://github.com/CrowdStrike/azure-vm-extension/releases/latest/download/csfalcon-azure-policy-bicep.zip)

2. **Extract Policy Files**: Extract the zip file which contains:
   - `falcon-subscription.bicep` - Subscription-level policy template
   - `falcon-managementgroup.bicep` - Management group-level policy template
   - `keyvault-deploy-access.bicep` - Key Vault access module used by both templates
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
- **Azure Key Vault references**: Credentials are read from Key Vault when the policy deploys the extension and are never stored on the policy assignment. See [Key Vault References](#key-vault-references)
- **Azure Key Vault on the VM**: The extension reads credentials from Key Vault on each machine using a managed identity (`azureVaultName`)

### Configuration Options
- **Falcon Cloud**: Auto-discover, US-1, US-2, EU-1, US-GOV-1
- **Member CID**: For MSSP scenarios
- **Sensor Update Policy**: Configure to match your organization's desired sensor update policy instead of using the pre-defined default
- **Tags**: Sensor grouping and organization
- **Proxy Settings**: HTTP proxy configuration
- **Platform-specific settings**: Windows PAC URL, VDI mode
- **Provisioning Token**: Optional installation token read from Key Vault (`provisioningTokenSecretName`)

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

The examples below read the Client ID and Secret from the `FALCON-CLIENT-ID` and `FALCON-CLIENT-SECRET` secrets in an Azure Key Vault. See [Key Vault References](#key-vault-references) for the vault requirements and other secret names, or [Automatic Identity Attachment](#automatic-identity-attachment-for-vms-and-vmss) to have the extension read the vault on each machine instead. One of `keyVaultResourceId` or `azureVaultName` is required.

### Option 1: Subscription Level (Recommended)

Deploy policies at the subscription level to cover all VMs and VMSS in the subscription:

#### Azure CLI
```bash
# Deploy both Linux and Windows policies
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"

# Deploy only Linux policy
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    operatingSystem="linux" \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" \
    cloud="gov1"

# Deploy only Windows policy
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    operatingSystem="windows" \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
```

#### PowerShell
```powershell
# Deploy both Linux and Windows policies
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"

# Deploy only Linux policy
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -operatingSystem "linux" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" `
  -cloud "gov1"

# Deploy only Windows policy
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "falcon-subscription.bicep" `
  -operatingSystem "windows" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
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
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"

# Deploy only Linux policy at management group level
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    operatingSystem="linux" \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" \
    cloud="gov1"

# Deploy only Windows policy at management group level
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-file falcon-managementgroup.bicep \
  --parameters \
    operatingSystem="windows" \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
```

#### PowerShell
```powershell
# Deploy both Linux and Windows policies at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"

# Deploy only Linux policy at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -operatingSystem "linux" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" `
  -cloud "gov1"

# Deploy only Windows policy at management group level
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateFile "falcon-managementgroup.bicep" `
  -operatingSystem "windows" `
  -keyVaultResourceId "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
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
| `azureVaultName` | string | Azure Key Vault name containing CrowdStrike credentials | '' |
| `azureManagedIdentityClientId` | string | Azure Managed Identity Client ID for Key Vault access (required when `azureManagedIdentityResourceId` is set) | '' |
| `azureManagedIdentityResourceId` | string | Full ARM resource ID of the user-assigned managed identity to attach to VMs/VMSS for Key Vault access (requires `azureManagedIdentityClientId`) | '' |
| `keyVaultResourceId` | string | Resource ID of a Key Vault to read credentials from during policy remediation. See [Key Vault References](#key-vault-references) | '' |
| `clientIdSecretName` | string | Key Vault secret name for the Client ID (requires `keyVaultResourceId`) | 'FALCON-CLIENT-ID' |
| `clientSecretSecretName` | string | Key Vault secret name for the Client Secret (requires `keyVaultResourceId`) | 'FALCON-CLIENT-SECRET' |
| `accessTokenSecretName` | string | Key Vault secret name for an Access Token, used instead of the Client ID and Secret (requires `keyVaultResourceId`) | '' |
| `provisioningTokenSecretName` | string | Key Vault secret name for the Provisioning Token (requires `keyVaultResourceId`) | '' |
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

When `azureManagedIdentityResourceId` is provided, each remediation:
1. Reads the identities currently attached to the VM or VMSS
2. Adds the specified user-assigned identity to them. Other user-assigned identities stay attached, and an existing system-assigned identity is kept, so its principal ID and role assignments are unchanged
3. Deploys the extension after the identity is attached

The identity is not written again when it is already attached. A VM or VMSS whose only identity is a single other user-assigned identity is skipped and the extension is not deployed on it, see [Troubleshooting](#vm-or-vmss-skipped-because-it-has-one-user-assigned-identity).

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

### Key Vault References

Set `keyVaultResourceId` to read the CrowdStrike credentials from Azure Key Vault when the policy deploys the extension. Azure Resource Manager resolves the secrets during each remediation using the policy assignment's managed identity. The policy definitions contain only the vault ID and secret names, and the credentials read from Key Vault are left out of the policy assignment entirely. VMs, VMSS, and Arc-connected servers do not need a managed identity or access to the vault.

```bash
# Client ID and Secret from the FALCON-CLIENT-ID and FALCON-CLIENT-SECRET secrets
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"

# Access token and provisioning token from Key Vault
az deployment sub create \
  --location "East US" \
  --template-file falcon-subscription.bicep \
  --parameters \
    keyVaultResourceId="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>" \
    accessTokenSecretName="FALCON-ACCESS-TOKEN" \
    provisioningTokenSecretName="FALCON-PROVISIONING-TOKEN"
```

The same parameters apply to `falcon-managementgroup.bicep`.

**Requirements:**
- The vault must allow template deployments: `az keyvault update --name <vault-name> --enabled-for-template-deployment true`
- The policy assignment identities need `Microsoft.KeyVault/vaults/deploy/action` on the vault. With `createRoleAssignments=true` (default), the template creates a custom **CrowdStrike Falcon Key Vault Template Deploy** role with only this action and assigns it on the vault. For management group deployments, the vault must be in a subscription under the management group. With `createRoleAssignments=false`, see [Manual Role Assignment](#manual-role-assignment).
- Every secret name in use must exist in the vault, otherwise the remediation deployment fails.

> [!NOTE]
> - When `accessTokenSecretName` is set, it is used instead of the Client ID and Secret.
> - Secrets are read when the extension is deployed. Rotating a secret affects later remediations; installed extensions keep the value they were deployed with.
> - The first remediation in a tenant can fail with `DeploymentServicePrincipalNotReady` while Azure registers its deployment service. Retry the remediation task after about 10 minutes.

> [!IMPORTANT]
> Earlier versions of these templates accepted credentials as parameters. Azure Policy does not allow removing parameters from an existing policy definition, so redeploying over one of those deployments fails with `InvalidPolicyParameterUpdate`. Remove the existing CrowdStrike policy assignments, the role assignments of their managed identities, and the policy definitions first, for example with [`scripts/cleanup-policy.sh`](../scripts/cleanup-policy.sh). Removing the old assignments also deletes the credentials stored on them.

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
| `disableProxy` | bool | Disable proxy settings | false |

## Role Assignment Configuration

### Understanding `createRoleAssignments` Parameter

The templates create managed identities that need **Virtual Machine Contributor** role to deploy VM and VMSS extensions, and **Azure Connected Machine Resource Administrator** role for Arc-connected server extensions. When using `azureManagedIdentityResourceId` for automatic identity attachment, the **Managed Identity Operator** role is also required. When using `keyVaultResourceId`, the identities also need `Microsoft.KeyVault/vaults/deploy/action` on the vault.

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

# If keyVaultResourceId is provided, allow each policy identity to resolve Key Vault references.
# Role names are unique per tenant, so the role is created once per subscription with the
# subscription ID in its name. A vault in another subscription adds that subscription to the
# assignable scopes. The role may take a minute to become available for assignment.
KEY_VAULT_ID="/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
KEY_VAULT_SUBSCRIPTION_SCOPE="/subscriptions/$(echo "$KEY_VAULT_ID" | cut -d/ -f3)"
KEY_VAULT_ROLE="CrowdStrike Falcon Key Vault Template Deploy Manual (${SUBSCRIPTION_SCOPE##*/})"

ASSIGNABLE_SCOPES="\"$SUBSCRIPTION_SCOPE\""
if [ "$KEY_VAULT_SUBSCRIPTION_SCOPE" != "$SUBSCRIPTION_SCOPE" ]; then
  ASSIGNABLE_SCOPES="$ASSIGNABLE_SCOPES, \"$KEY_VAULT_SUBSCRIPTION_SCOPE\""
fi

az role definition create --role-definition "{
  \"Name\": \"$KEY_VAULT_ROLE\",
  \"IsCustom\": true,
  \"Description\": \"Allows Azure Resource Manager to resolve Key Vault references during CrowdStrike Falcon policy remediation\",
  \"Actions\": [\"Microsoft.KeyVault/vaults/deploy/action\"],
  \"AssignableScopes\": [$ASSIGNABLE_SCOPES]
}"

# Principal IDs are empty for policies that were not deployed (operatingSystem, deployToArc)
for PRINCIPAL_ID in "$LINUX_VM_PRINCIPAL_ID" "$LINUX_VMSS_PRINCIPAL_ID" "$WINDOWS_VM_PRINCIPAL_ID" "$WINDOWS_VMSS_PRINCIPAL_ID" "$LINUX_ARC_PRINCIPAL_ID" "$WINDOWS_ARC_PRINCIPAL_ID"; do
  [ -z "$PRINCIPAL_ID" ] && continue
  az role assignment create --assignee "$PRINCIPAL_ID" --role "$KEY_VAULT_ROLE" --scope "$KEY_VAULT_ID"
done
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

# If keyVaultResourceId is provided, allow each policy identity to resolve Key Vault references.
# Role names are unique per tenant, so the role is created once per subscription with the
# subscription ID in its name. A vault in another subscription adds that subscription to the
# assignable scopes. The role may take a minute to become available for assignment.
$keyVaultId = "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
$keyVaultSubscriptionScope = "/subscriptions/$($keyVaultId.Split('/')[2])"
$keyVaultRoleName = "CrowdStrike Falcon Key Vault Template Deploy Manual ($((Get-AzContext).Subscription.Id))"

$role = Get-AzRoleDefinition -Name "Reader"
$role.Id = $null
$role.Name = $keyVaultRoleName
$role.Description = "Allows Azure Resource Manager to resolve Key Vault references during CrowdStrike Falcon policy remediation"
$role.Actions.Clear()
$role.Actions.Add("Microsoft.KeyVault/vaults/deploy/action")
$role.NotActions.Clear()
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add($subscriptionScope)
if ($keyVaultSubscriptionScope -ne $subscriptionScope) {
  $role.AssignableScopes.Add($keyVaultSubscriptionScope)
}
New-AzRoleDefinition -Role $role

# Principal IDs are empty for policies that were not deployed (operatingSystem, deployToArc)
foreach ($principalId in @($linuxVmPrincipalId, $linuxVmssPrincipalId, $windowsVmPrincipalId, $windowsVmssPrincipalId, $linuxArcPrincipalId, $windowsArcPrincipalId)) {
  if ($principalId) {
    New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName $keyVaultRoleName -Scope $keyVaultId
  }
}
```

> [!NOTE]
> For management group deployments, read the principal IDs from `az deployment mg show` (or `Get-AzManagementGroupDeployment`), assign the roles at the management group scope, and use the management group as the only assignable scope of the Key Vault role. The vault must be in a subscription under the management group.

## Troubleshooting

### VM or VMSS skipped because it has one user-assigned identity

When `azureManagedIdentityResourceId` is set, the policy leaves a VM or VMSS unchanged if its only identity is a single user-assigned identity, and does not deploy the extension on it. On such a machine, token requests to the Azure Instance Metadata Service (IMDS) that do not name an identity use that single identity. Attaching a second identity makes those requests fail with `Multiple user assigned identities exist, please specify the clientId / resourceId of the identity in the token request`.

These machines stay non-compliant. The remediation's `cs-falcon-install-*` deployment in the machine's resource group reports the reason in its `skipReason` output:

```bash
az deployment group list --resource-group <rg> \
  --query "[?starts_with(name, 'cs-falcon-install-')].{name:name, skipReason:properties.outputs.skipReason.value}" \
  --output table
```

To install the sensor on one of these machines, either:
- Update the applications on the machine to name their identity in token requests, attach the CrowdStrike identity, and run a remediation task:
  ```bash
  az vm identity assign --resource-group <rg> --name <vm-name> --identities <identity-resource-id>
  az vmss identity assign --resource-group <rg> --name <vmss-name> --identities <identity-resource-id>
  ```
- Or install the extension directly. The policy treats a machine with a successfully installed extension as compliant.

### Remediation fails on VMs that take more than 10 minutes to provision

For a new or updated VM or VMSS, Azure Policy deploys the extension 10 minutes after the create or update request. If provisioning is still running at that point, the deployment can fail, and Azure Policy does not retry it. Run a remediation task after provisioning completes.
