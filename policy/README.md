# CrowdStrike Falcon Azure Policy Templates

This folder contains Azure Policy templates for automated deployment of CrowdStrike Falcon sensors using the official CrowdStrike VM extensions at scale.

## Contents

### Policy Templates
- **`falcon-subscription.bicep`** - Creates policy definitions and assignments at subscription level
- **`falcon-managementgroup.bicep`** - Creates policy assignments at management group level

### User Interface Definitions
- **`ui.json`** - Comprehensive UI definition for management group deployment
- **`ui-subscription.json`** - Simplified UI definition for subscription deployment

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
    clientSecret="your-client-secret"
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

### Option 2: Management Group Level

Deploy policy assignments at the management group level for enterprise-wide deployment. **Note**: Requires existing policy definitions from subscription level deployment first.

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

## Azure Portal Deployment

1. Navigate to Azure Portal > Create a resource
2. Search for "Template deployment"
3. Select "Build your own template in the editor"
4. Upload the appropriate `.bicep` file
5. Use the corresponding UI definition file
6. Configure parameters and deploy

## Prerequisites

### CrowdStrike API Credentials
You need either:
- **OAuth2 Client Credentials**: Client ID and Secret with appropriate permissions
- **Access Token**: Valid API token

### Required API Permissions
- `Sensor Update Policy - Read`
- `Sensor Update Policy - Write` (for uninstall operations)

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
