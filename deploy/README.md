# Deploy CrowdStrike Falcon Azure Policy

Deploy CrowdStrike Falcon Azure Policy to automatically install and configure the CrowdStrike Falcon sensor on Azure VMs, VM Scale Sets, and Arc-connected servers using Azure Policy.

## Deploy to Azure

### Subscription Deployment (Recommended)

Deploy policies at subscription scope to cover all VMs and VMSS in a single subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FmainTemplate.sub.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FcreateUiDefinition.json)

[![Deploy to Azure](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FmainTemplate.sub.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FcreateUiDefinition.json)

### Management Group Deployment

Deploy policies at management group scope for enterprise-wide deployment across multiple subscriptions. This uses the Azure portal's **CustomDeploymentBlade** route with a Form view (`uiFormDefinition.mg.json`) so the wizard can present a management group picker (including the tenant root group) — the same mechanism the [Azure Landing Zones accelerator](https://azure.github.io/Azure-Landing-Zones/accelerator/) uses to target management group scope.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FmainTemplate.mg.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FCrowdStrike%2Fazure-vm-extension%2Fmain%2Fdeploy%2FuiFormDefinition.mg.json)

### Testing from a fork (pre-merge)

The buttons above resolve against `CrowdStrike/azure-vm-extension@main` and only work once this change is merged. To test from a fork or branch beforehand, take a button URL and replace the `CrowdStrike/azure-vm-extension/main` path segment with `<your-org>/azure-vm-extension/<your-branch>`, keeping the URL encoding intact. For example, the subscription template segment becomes:

```
https%3A%2F%2Fraw.githubusercontent.com%2F<your-org>%2Fazure-vm-extension%2F<your-branch>%2Fdeploy%2FmainTemplate.sub.json
```

## What This Deployment Creates

This deployment creates up to **6 Azure Policy definitions** for comprehensive coverage:

1. **Linux VM Policy** - Deploys Falcon sensor on individual Linux virtual machines
2. **Linux VMSS Policy** - Deploys Falcon sensor on Linux Virtual Machine Scale Sets  
3. **Windows VM Policy** - Deploys Falcon sensor on individual Windows virtual machines
4. **Windows VMSS Policy** - Deploys Falcon sensor on Windows Virtual Machine Scale Sets
5. **Linux Arc Policy** - Deploys Falcon sensor on Linux Azure Arc-connected servers
6. **Windows Arc Policy** - Deploys Falcon sensor on Windows Azure Arc-connected servers

All policies use **DeployIfNotExists** effect with system-assigned managed identities and automatically create the required role assignments.

## Prerequisites

### CrowdStrike API Credentials

You'll need CrowdStrike API credentials with the following permissions:
- **Sensor Download** [read] - Required
- **Sensor update policies** [read] - Required  
- **Installation Tokens** [read] - Optional, for retrieving provisioning tokens
- **Sensor update policies** [write] - Optional, required for sensor uninstall

Get credentials from your [CrowdStrike Falcon console](https://falcon.crowdstrike.com/support/api-clients-and-keys) under **Support > API Clients & Keys**.

### Azure Permissions

#### For Subscription-Level Deployment
- **Owner** or **User Access Administrator** role (recommended)
- Or custom role with these permissions:
  - `Microsoft.Authorization/policyDefinitions/write`
  - `Microsoft.Authorization/policyAssignments/write`
  - `Microsoft.Authorization/roleAssignments/write`
  - `Microsoft.Compute/virtualMachines/extensions/write`

#### For Management Group-Level Deployment  
- **Owner** or **User Access Administrator** role at management group scope
- Or custom role with these permissions at management group scope:
  - `Microsoft.Authorization/policyDefinitions/write`
  - `Microsoft.Authorization/policyAssignments/write`  
  - `Microsoft.Authorization/roleAssignments/write`
  - `Microsoft.Resources/deployments/write`
  - `Microsoft.Compute/virtualMachines/extensions/write` (inherited by subscriptions)

## Deployment Wizard

The custom deployment wizard guides you through:

### 1. CrowdStrike Configuration
- **Authentication Method**: Choose between OAuth2 credentials, access token, or Azure Key Vault
- **Cloud Region**: Select your CrowdStrike cloud (auto-discover, us-1, us-2, eu-1, us-gov-1)  
- **Sensor Update Policy**: Specify your organization's sensor update policy
- **Sensor Tags**: Optional tags for sensor organization

### 2. Deployment Options
- **Operating Systems**: Deploy to Linux, Windows, or both
- **Azure Arc**: Include Arc-connected servers
- **Policy Effect**: DeployIfNotExists (auto-install), AuditIfNotExists (report only), or Disabled
- **Enforcement Mode**: Enforce immediately or create in DoNotEnforce mode

### 3. Advanced Options
- **MSSP Support**: Member CID for parent/child scenarios
- **Provisioning Token**: Linux installation token (if required)
- **Proxy Configuration**: HTTP proxy settings and PAC URL for Windows

## Post-Deployment

### Compliance Evaluation
After deployment, Azure Policy performs compliance evaluation:
- **Initial evaluation**: Within 15 minutes for new assignments  
- **Existing resources**: Up to 24 hours for full compliance scan
- **Ongoing evaluation**: Every 24 hours, plus on resource changes

### Remediation
For existing non-compliant resources, trigger remediation:

```bash
# Create remediation task for non-compliant resources
az policy remediation create \
  --name "falcon-remediation-$(date +%Y%m%d)" \
  --policy-assignment "/subscriptions/{subscription-id}/providers/Microsoft.Authorization/policyAssignments/CS-Falcon-Policy" \
  --resource-discovery-mode "ReEvaluateCompliance"
```

### Verify Deployment
Check policy assignments and compliance:

```bash
# List policy assignments
az policy assignment list --scope "/subscriptions/{subscription-id}"

# View policy compliance
az policy state summarize --policy-assignment "CS-Falcon-Policy"

# Check VM extensions
az vm extension list --resource-group {resource-group} --vm-name {vm-name}
```

## Command Line Deployment

### Azure CLI

**Subscription Deployment:**
```bash
az deployment sub create \
  --location "East US" \
  --template-uri "https://raw.githubusercontent.com/CrowdStrike/azure-vm-extension/main/deploy/mainTemplate.sub.json" \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret" \
    cloud="autodiscover" \
    operatingSystem="both"
```

**Management Group Deployment:**
```bash
az deployment mg create \
  --management-group-id "my-management-group" \
  --location "East US" \
  --template-uri "https://raw.githubusercontent.com/CrowdStrike/azure-vm-extension/main/deploy/mainTemplate.mg.json" \
  --parameters \
    clientId="your-client-id" \
    clientSecret="your-client-secret" \
    cloud="autodiscover" \
    operatingSystem="both"
```

### PowerShell

**Subscription Deployment:**
```powershell
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateUri "https://raw.githubusercontent.com/CrowdStrike/azure-vm-extension/main/deploy/mainTemplate.sub.json" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret" `
  -cloud "autodiscover" `
  -operatingSystem "both"
```

**Management Group Deployment:**
```powershell
New-AzManagementGroupDeployment `
  -ManagementGroupId "my-management-group" `
  -Location "East US" `
  -TemplateUri "https://raw.githubusercontent.com/CrowdStrike/azure-vm-extension/main/deploy/mainTemplate.mg.json" `
  -clientId "your-client-id" `
  -clientSecret "your-client-secret" `
  -cloud "autodiscover" `
  -operatingSystem "both"
```

## Azure Key Vault Integration

For enhanced security, store CrowdStrike credentials in Azure Key Vault:

### 1. Create Key Vault and Store Secrets
```bash
# Create Key Vault
az keyvault create \
  --name "my-crowdstrike-vault" \
  --resource-group "my-resource-group" \
  --location "East US"

# Store credentials (note the FALCON- prefix requirement)
az keyvault secret set --vault-name "my-crowdstrike-vault" --name "FALCON-CLIENT-ID" --value "your-client-id"
az keyvault secret set --vault-name "my-crowdstrike-vault" --name "FALCON-CLIENT-SECRET" --value "your-client-secret"
```

### 2. Grant VM Access
VMs need **Key Vault Secrets User** role to read secrets:

```bash
# Grant access to all VMs in subscription (using built-in role)
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000000" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.KeyVault/vaults/my-crowdstrike-vault"
```

### 3. Deploy Using Key Vault
```bash
az deployment sub create \
  --location "East US" \
  --template-uri "https://raw.githubusercontent.com/CrowdStrike/azure-vm-extension/main/deploy/mainTemplate.sub.json" \
  --parameters \
    azureVaultName="my-crowdstrike-vault" \
    operatingSystem="both"
```

## Troubleshooting

### Common Issues

**Policy Assignment Not Found:**
- Ensure you have sufficient permissions at the deployment scope
- Check that the deployment completed successfully
- Verify the policy assignment exists: `az policy assignment list`

**Extension Installation Fails:**
- Check VM connectivity to CrowdStrike APIs
- Verify API credentials are correct and have required permissions
- For Key Vault: ensure VM has access to retrieve secrets
- Review extension logs on the VM (see main repository documentation)

**Missing Role Assignments:**
- If `createRoleAssignments=false`, manually assign roles:
  - **Virtual Machine Contributor** for VM/VMSS policies
  - **Azure Connected Machine Resource Administrator** for Arc policies
  - **Managed Identity Operator** when using user-assigned identities

**Management Group Permission Errors:**
- Management group deployments require elevated permissions
- Ensure your account has Owner/User Access Administrator at MG scope
- Check that the management group ID is correct

### Support
For issues with the extension deployment or CrowdStrike-specific problems, see the main [repository documentation](https://github.com/CrowdStrike/azure-vm-extension).

For Azure Policy-specific issues, refer to the [Azure Policy documentation](https://docs.microsoft.com/azure/governance/policy/).

## Uninstall

To remove the CrowdStrike Falcon policies:

### 1. Delete Policy Assignments
```bash
az policy assignment delete --name "CS-Falcon-Policy-linux-vm"
az policy assignment delete --name "CS-Falcon-Policy-windows-vm"
# Repeat for all created assignments
```

### 2. Delete Role Assignments
```bash  
# List and delete role assignments created by the policy
az role assignment list --assignee {policy-identity-id} --output table
az role assignment delete --assignee {policy-identity-id} --role "Virtual Machine Contributor"
```

### 3. Delete Policy Definitions
```bash
az policy definition delete --name "CS-Falcon-Policy-Linux"
az policy definition delete --name "CS-Falcon-Policy-Windows"  
# Repeat for all created definitions
```

## Alternative Deployment Methods

This Deploy to Azure button complements the existing deployment options:

- **[Bicep Policy Templates](../policy/)** - Direct Bicep deployment for IaC workflows
- **[VM Extension Templates](../linux/package/)** - Direct VM extension deployment  
- **[Azure CLI Commands](../README.md#usage)** - Command-line VM extension deployment

The policy-based approach provided here offers automatic detection and deployment across your Azure environment, while the other methods require manual deployment to individual VMs or VMSS.