targetScope = 'subscription'

@description('Operating systems to deploy policies for')
@allowed([
  'linux'
  'windows'
  'both'
])
param operatingSystem string = 'both'

@description('Policy definition name prefix')
param policyDefinitionNamePrefix string = 'CS-Falcon-Policy-Test'

@description('Effect for the policy assignment (DeployIfNotExists, AuditIfNotExists, Disabled)')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param policyEffect string = 'DeployIfNotExists'

@description('Create role assignments for policy managed identities (requires Owner or User Access Administrator role)')
param createRoleAssignments bool = true

@description('Deploy to Azure Arc-connected servers')
param deployToArc bool = true

@description('Extension configuration settings')
param extensionSettings object = {
  handlerVersion: '0.0'
  autoUpgradeMinorVersion: true
}

// CrowdStrike Parameters
param azureVaultName string = ''
param cloud string = 'autodiscover'
param memberCid string = ''
param sensorUpdatePolicy string = 'platform_default'
param disableProxy bool = false
param azureManagedIdentityClientId string = ''
@description('Full ARM resource ID of the user-assigned managed identity to attach to VMs for Key Vault access')
param azureManagedIdentityResourceId string = ''
@description('Resource ID of a Key Vault to read CrowdStrike credentials from during policy remediation. Use azureVaultName instead to have the extension read the vault on each machine')
param keyVaultResourceId string = ''
@description('Key Vault secret name for the CrowdStrike API Client ID (requires keyVaultResourceId)')
param clientIdSecretName string = 'FALCON-CLIENT-ID'
@description('Key Vault secret name for the CrowdStrike API Client Secret (requires keyVaultResourceId)')
param clientSecretSecretName string = 'FALCON-CLIENT-SECRET'
@description('Key Vault secret name for a CrowdStrike API Access Token. When set, it is used instead of the Client ID and Secret (requires keyVaultResourceId)')
param accessTokenSecretName string = ''
@description('Key Vault secret name for the CrowdStrike Provisioning Token (requires keyVaultResourceId)')
param provisioningTokenSecretName string = ''
param proxySettings object = {
  proxyHost: ''
  proxyPort: ''
}
param tags string = ''
param pacUrl string = ''
param disableProvisioningWait bool = false
param disableStart bool = false
param provisioningWaitTime string = '1200000'
param vdi bool = false

// Variables
var operatingSystemLower = toLower(operatingSystem)
var vmRoleDefinitionId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // Virtual Machine Contributor
var arcRoleDefinitionId = 'cd570a14-e51a-42ad-bac8-bafd67325302' // Azure Connected Machine Resource Administrator
var managedIdentityOperatorRoleId = 'f1a07417-d97a-45cb-824c-7a7467783830' // Managed Identity Operator
var linuxPolicyDefinitionName = '${policyDefinitionNamePrefix}-Linux'
var windowsPolicyDefinitionName = '${policyDefinitionNamePrefix}-Windows'

// Credentials are resolved by ARM from keyVaultResourceId during remediation, so they are never
// stored on the policy assignment. An access token takes precedence over the Client ID and Secret.
var useKeyVaultReferences = !empty(keyVaultResourceId)
var accessTokenFromKeyVault = useKeyVaultReferences && !empty(accessTokenSecretName)
var clientIdFromKeyVault = useKeyVaultReferences && !accessTokenFromKeyVault && !empty(clientIdSecretName)
var clientSecretFromKeyVault = useKeyVaultReferences && !accessTokenFromKeyVault && !empty(clientSecretSecretName)
var provisioningTokenFromKeyVault = useKeyVaultReferences && !empty(provisioningTokenSecretName)
// Placeholder keeps the index lookups valid when Key Vault references are not used
var keyVaultIdParts = split(useKeyVaultReferences ? keyVaultResourceId : '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/unused/providers/Microsoft.KeyVault/vaults/unused', '/')

var policyMetadata = {
  category: 'Security'
  version: '1.0.0'
}

var commonParameters = {
  effect: {
    type: 'String'
    metadata: {
      displayName: 'Effect'
      description: 'Enable or disable the execution of the policy'
    }
    allowedValues: [
      'DeployIfNotExists'
      'AuditIfNotExists'
      'Disabled'
    ]
    defaultValue: 'DeployIfNotExists'
  }
  azureVaultName: {
    type: 'String'
    metadata: {
      displayName: 'Azure Key Vault Name'
      description: 'Azure Key Vault name for credential storage'
    }
    defaultValue: ''
  }
  azureManagedIdentityClientId: {
    type: 'String'
    metadata: {
      displayName: 'Azure Managed Identity Client ID'
      description: 'Azure User Assigned Managed Identity Client ID for Key Vault access'
    }
    defaultValue: ''
  }
  azureManagedIdentityResourceId: {
    type: 'String'
    metadata: {
      displayName: 'User-Assigned Managed Identity Resource ID'
      description: 'Full ARM resource ID of the user-assigned managed identity to attach to VMs for Key Vault access'
    }
    defaultValue: ''
  }
  cloud: {
    type: 'String'
    metadata: {
      displayName: 'CrowdStrike Cloud'
      description: 'CrowdStrike Cloud region'
    }
    defaultValue: 'autodiscover'
  }
  memberCid: {
    type: 'String'
    metadata: {
      displayName: 'Member CID'
      description: 'CrowdStrike Member CID'
    }
    defaultValue: ''
  }
  sensorUpdatePolicy: {
    type: 'String'
    metadata: {
      displayName: 'Sensor Update Policy'
      description: 'CrowdStrike Sensor Update Policy'
    }
    defaultValue: 'platform_default'
  }
  disableProxy: {
    type: 'Boolean'
    metadata: {
      displayName: 'Disable Proxy'
      description: 'Disable proxy settings'
    }
    defaultValue: false
  }
  proxySettings: {
    type: 'Object'
    metadata: {
      displayName: 'Proxy Settings'
      description: 'Network proxy configuration settings'
    }
    defaultValue: {
      proxyHost: ''
      proxyPort: ''
    }
  }
  tags: {
    type: 'String'
    metadata: {
      displayName: 'Tags'
      description: 'Comma-separated list of tags'
    }
    defaultValue: ''
  }
  extensionSettings: {
    type: 'Object'
    metadata: {
      displayName: 'Extension Settings'
      description: 'CrowdStrike Falcon extension configuration settings'
    }
    defaultValue: {
      handlerVersion: '0.0'
      autoUpgradeMinorVersion: true
    }
  }
}

var windowsSpecificParameters = {
  pacUrl: {
    type: 'String'
    metadata: {
      displayName: 'PAC URL'
      description: 'PAC URL for Windows'
    }
    defaultValue: ''
  }
  disableProvisioningWait: {
    type: 'Boolean'
    metadata: {
      displayName: 'Disable Provisioning Wait'
      description: 'Disable provisioning wait for Windows'
    }
    defaultValue: false
  }
  disableStart: {
    type: 'Boolean'
    metadata: {
      displayName: 'Disable Start'
      description: 'Disable start for Windows'
    }
    defaultValue: false
  }
  provisioningWaitTime: {
    type: 'String'
    metadata: {
      displayName: 'Provisioning Wait Time'
      description: 'Provisioning wait time for Windows'
    }
    defaultValue: '1200000'
  }
  vdi: {
    type: 'Boolean'
    metadata: {
      displayName: 'VDI'
      description: 'VDI setting for Windows'
    }
    defaultValue: false
  }
}

var commonTemplateParameters = {
  resourceName: { type: 'string' }
  location: { type: 'string' }
  clientId: { type: 'securestring' }
  clientSecret: { type: 'securestring' }
  accessToken: { type: 'securestring' }
  azureVaultName: { type: 'string' }
  azureManagedIdentityClientId: { type: 'string' }
  azureManagedIdentityResourceId: { type: 'string' }
  cloud: { type: 'string' }
  memberCid: { type: 'string' }
  sensorUpdatePolicy: { type: 'string' }
  disableProxy: { type: 'bool' }
  provisioningToken: { type: 'securestring' }
  proxySettings: { type: 'object' }
  tags: { type: 'string' }
  extensionSettings: { type: 'object' }
}

var windowsTemplateParameters = union(commonTemplateParameters, {
  pacUrl: { type: 'string' }
  disableProvisioningWait: { type: 'bool' }
  disableStart: { type: 'bool' }
  provisioningWaitTime: { type: 'string' }
  vdi: { type: 'bool' }
})

var keyVaultReferenceId = { id: keyVaultResourceId }
var clientIdKeyVaultReference = { reference: { keyVault: keyVaultReferenceId, secretName: clientIdSecretName } }
var clientSecretKeyVaultReference = { reference: { keyVault: keyVaultReferenceId, secretName: clientSecretSecretName } }
var accessTokenKeyVaultReference = { reference: { keyVault: keyVaultReferenceId, secretName: accessTokenSecretName } }
var provisioningTokenKeyVaultReference = { reference: { keyVault: keyVaultReferenceId, secretName: provisioningTokenSecretName } }

var commonTemplateParameterValues = {
  resourceName: { value: '[field(\'name\')]' }
  location: { value: '[field(\'location\')]' }
  clientId: clientIdFromKeyVault ? clientIdKeyVaultReference : { value: '' }
  clientSecret: clientSecretFromKeyVault ? clientSecretKeyVaultReference : { value: '' }
  accessToken: accessTokenFromKeyVault ? accessTokenKeyVaultReference : { value: '' }
  azureVaultName: { value: '[parameters(\'azureVaultName\')]' }
  azureManagedIdentityClientId: { value: '[parameters(\'azureManagedIdentityClientId\')]' }
  azureManagedIdentityResourceId: { value: '[parameters(\'azureManagedIdentityResourceId\')]' }
  cloud: { value: '[parameters(\'cloud\')]' }
  memberCid: { value: '[parameters(\'memberCid\')]' }
  sensorUpdatePolicy: { value: '[parameters(\'sensorUpdatePolicy\')]' }
  disableProxy: { value: '[parameters(\'disableProxy\')]' }
  provisioningToken: provisioningTokenFromKeyVault ? provisioningTokenKeyVaultReference : { value: '' }
  proxySettings: { value: '[parameters(\'proxySettings\')]' }
  tags: { value: '[parameters(\'tags\')]' }
  extensionSettings: { value: '[parameters(\'extensionSettings\')]' }
}

var windowsTemplateParameterValues = union(commonTemplateParameterValues, {
  pacUrl: { value: '[parameters(\'pacUrl\')]' }
  disableProvisioningWait: { value: '[parameters(\'disableProvisioningWait\')]' }
  disableStart: { value: '[parameters(\'disableStart\')]' }
  provisioningWaitTime: { value: '[parameters(\'provisioningWaitTime\')]' }
  vdi: { value: '[parameters(\'vdi\')]' }
})

// VM and VMSS remediation runs in two nested deployments so the identity attachment adds to the
// identities already on the resource instead of replacing them. The read deployment returns the
// resource's current identity, and the install deployment merges into it and deploys the extension.
var remediationDeploymentNames = {
  identityReadDeploymentName: '[concat(\'cs-falcon-read-\', uniqueString(deployment().name))]'
  falconInstallDeploymentName: '[concat(\'cs-falcon-install-\', uniqueString(deployment().name))]'
}

var vmIdentityReadDeployment = {
  name: '[variables(\'identityReadDeploymentName\')]'
  type: 'Microsoft.Resources/deployments'
  apiVersion: '2022-09-01'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        identity: {
          type: 'object'
          value: '[if(contains(reference(resourceId(\'Microsoft.Compute/virtualMachines\', parameters(\'resourceName\')), \'2023-09-01\', \'Full\'), \'identity\'), reference(resourceId(\'Microsoft.Compute/virtualMachines\', parameters(\'resourceName\')), \'2023-09-01\', \'Full\').identity, createObject())]'
        }
      }
    }
  }
}

var vmssIdentityReadDeployment = {
  name: '[variables(\'identityReadDeploymentName\')]'
  type: 'Microsoft.Resources/deployments'
  apiVersion: '2022-09-01'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        identity: {
          type: 'object'
          value: '[if(contains(reference(resourceId(\'Microsoft.Compute/virtualMachineScaleSets\', parameters(\'resourceName\')), \'2023-09-01\', \'Full\'), \'identity\'), reference(resourceId(\'Microsoft.Compute/virtualMachineScaleSets\', parameters(\'resourceName\')), \'2023-09-01\', \'Full\').identity, createObject())]'
        }
      }
    }
  }
}

var commonInstallTemplateParameters = union(commonTemplateParameters, {
  currentIdentity: { type: 'object' }
})

var windowsInstallTemplateParameters = union(windowsTemplateParameters, {
  currentIdentity: { type: 'object' }
})

var commonInstallParameterValues = {
  resourceName: { value: '[parameters(\'resourceName\')]' }
  location: { value: '[parameters(\'location\')]' }
  clientId: { value: '[parameters(\'clientId\')]' }
  clientSecret: { value: '[parameters(\'clientSecret\')]' }
  accessToken: { value: '[parameters(\'accessToken\')]' }
  azureVaultName: { value: '[parameters(\'azureVaultName\')]' }
  azureManagedIdentityClientId: { value: '[parameters(\'azureManagedIdentityClientId\')]' }
  azureManagedIdentityResourceId: { value: '[parameters(\'azureManagedIdentityResourceId\')]' }
  cloud: { value: '[parameters(\'cloud\')]' }
  memberCid: { value: '[parameters(\'memberCid\')]' }
  sensorUpdatePolicy: { value: '[parameters(\'sensorUpdatePolicy\')]' }
  disableProxy: { value: '[parameters(\'disableProxy\')]' }
  provisioningToken: { value: '[parameters(\'provisioningToken\')]' }
  proxySettings: { value: '[parameters(\'proxySettings\')]' }
  tags: { value: '[parameters(\'tags\')]' }
  extensionSettings: { value: '[parameters(\'extensionSettings\')]' }
  currentIdentity: { value: '[reference(variables(\'identityReadDeploymentName\')).outputs.identity.value]' }
}

var windowsInstallParameterValues = union(commonInstallParameterValues, {
  pacUrl: { value: '[parameters(\'pacUrl\')]' }
  disableProvisioningWait: { value: '[parameters(\'disableProvisioningWait\')]' }
  disableStart: { value: '[parameters(\'disableStart\')]' }
  provisioningWaitTime: { value: '[parameters(\'provisioningWaitTime\')]' }
  vdi: { value: '[parameters(\'vdi\')]' }
})

// A resource whose only identity is a single user-assigned identity is skipped entirely: IMDS uses
// that identity by default, and attaching a second one breaks token requests that do not name one.
var identityMergeVariables = {
  existingIdentities: '[if(contains(parameters(\'currentIdentity\'), \'userAssignedIdentities\'), parameters(\'currentIdentity\').userAssignedIdentities, createObject())]'
  identityType: '[if(contains(parameters(\'currentIdentity\'), \'type\'), parameters(\'currentIdentity\').type, \'\')]'
  identityAlreadyAttached: '[contains(variables(\'existingIdentities\'), parameters(\'azureManagedIdentityResourceId\'))]'
  singleOtherIdentity: '[and(equals(variables(\'identityType\'), \'UserAssigned\'), equals(length(variables(\'existingIdentities\')), 1), not(variables(\'identityAlreadyAttached\')))]'
  attachIdentity: '[and(not(empty(parameters(\'azureManagedIdentityResourceId\'))), not(variables(\'identityAlreadyAttached\')), not(variables(\'singleOtherIdentity\')))]'
  installExtension: '[or(empty(parameters(\'azureManagedIdentityResourceId\')), not(variables(\'singleOtherIdentity\')))]'
  identityTypeValue: '[if(contains(variables(\'identityType\'), \'SystemAssigned\'), \'SystemAssigned,UserAssigned\', \'UserAssigned\')]'
  userAssignedIdentitiesValue: '[if(variables(\'attachIdentity\'), union(variables(\'existingIdentities\'), createObject(parameters(\'azureManagedIdentityResourceId\'), createObject())), variables(\'existingIdentities\'))]'
}

var vmIdentityWrite = {
  condition: '[variables(\'attachIdentity\')]'
  name: '[parameters(\'resourceName\')]'
  type: 'Microsoft.Compute/virtualMachines'
  apiVersion: '2023-09-01'
  location: '[parameters(\'location\')]'
  identity: {
    type: '[variables(\'identityTypeValue\')]'
    userAssignedIdentities: '[variables(\'userAssignedIdentitiesValue\')]'
  }
}

var vmssIdentityWrite = {
  condition: '[variables(\'attachIdentity\')]'
  name: '[parameters(\'resourceName\')]'
  type: 'Microsoft.Compute/virtualMachineScaleSets'
  apiVersion: '2023-09-01'
  location: '[parameters(\'location\')]'
  identity: {
    type: '[variables(\'identityTypeValue\')]'
    userAssignedIdentities: '[variables(\'userAssignedIdentitiesValue\')]'
  }
}

var identitySkipOutputs = {
  skipReason: {
    type: 'string'
    value: '[if(variables(\'installExtension\'), \'\', \'Skipped: the resource has a single user-assigned managed identity and no system-assigned identity. Attaching the CrowdStrike identity would change the identity that IMDS uses by default. See the Troubleshooting section of the policy README.\')]'
  }
}

var commonLinuxAssignmentParameters = {
  effect: { value: policyEffect }
  azureVaultName: { value: azureVaultName }
  azureManagedIdentityClientId: { value: azureManagedIdentityClientId }
  azureManagedIdentityResourceId: { value: azureManagedIdentityResourceId }
  cloud: { value: cloud }
  memberCid: { value: memberCid }
  sensorUpdatePolicy: { value: sensorUpdatePolicy }
  disableProxy: { value: disableProxy }
  proxySettings: { value: proxySettings }
  tags: { value: tags }
  extensionSettings: { value: extensionSettings }
}

var commonWindowsAssignmentParameters = union(commonLinuxAssignmentParameters, {
  pacUrl: { value: pacUrl }
  disableProvisioningWait: { value: disableProvisioningWait }
  disableStart: { value: disableStart }
  provisioningWaitTime: { value: provisioningWaitTime }
  vdi: { value: vdi }
})

// Create Linux VM policy definition
resource linuxVmPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: '${linuxPolicyDefinitionName}-VM'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux VMs'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Linux VMs if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: commonParameters
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/osProfile.linuxConfiguration'
            exists: 'true'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/virtualMachineScaleSet.id'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'TestFalconSensorLinux'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: commonTemplateParameters
                variables: remediationDeploymentNames
                resources: [
                  vmIdentityReadDeployment
                  {
                    name: '[variables(\'falconInstallDeploymentName\')]'
                    type: 'Microsoft.Resources/deployments'
                    apiVersion: '2022-09-01'
                    dependsOn: [
                      '[variables(\'identityReadDeploymentName\')]'
                    ]
                    properties: {
                      mode: 'Incremental'
                      expressionEvaluationOptions: {
                        scope: 'inner'
                      }
                      parameters: commonInstallParameterValues
                      template: {
                        '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        contentVersion: '1.0.0.0'
                        parameters: commonInstallTemplateParameters
                        variables: identityMergeVariables
                        resources: [
                          vmIdentityWrite
                          {
                            condition: '[variables(\'installExtension\')]'
                            name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                            type: 'Microsoft.Compute/virtualMachines/extensions'
                            location: '[parameters(\'location\')]'
                            apiVersion: '2021-07-01'
                            dependsOn: [
                              '[parameters(\'resourceName\')]'
                            ]
                            properties: {
                              publisher: 'Crowdstrike.Falcon'
                              type: 'TestFalconSensorLinux'
                              typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                              autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                              settings: {
                                azure_vault_name: '[parameters(\'azureVaultName\')]'
                                azure_managed_identity_client_id: '[parameters(\'azureManagedIdentityClientId\')]'
                                cloud: '[parameters(\'cloud\')]'
                                member_cid: '[parameters(\'memberCid\')]'
                                sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                                disable_proxy: '[parameters(\'disableProxy\')]'
                                proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                                proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                                tags: '[parameters(\'tags\')]'
                              }
                              protectedSettings: {
                                client_id: '[parameters(\'clientId\')]'
                                client_secret: '[parameters(\'clientSecret\')]'
                                access_token: '[parameters(\'accessToken\')]'
                                provisioning_token: '[parameters(\'provisioningToken\')]'
                              }
                            }
                          }
                        ]
                        outputs: identitySkipOutputs
                      }
                    }
                  }
                ]
              }
              parameters: commonTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Linux VMSS policy definition
resource linuxVmssPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: '${linuxPolicyDefinitionName}-VMSS'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux VMSS'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Linux Virtual Machine Scale Sets if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: commonParameters
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachineScaleSets'
          }
          {
            field: 'Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.osProfile.linuxConfiguration'
            exists: 'true'
          }
          {
            field: 'tags[\'aks-managed-poolName\']'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/type'
                equals: 'TestFalconSensorLinux'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: commonTemplateParameters
                variables: remediationDeploymentNames
                resources: [
                  vmssIdentityReadDeployment
                  {
                    name: '[variables(\'falconInstallDeploymentName\')]'
                    type: 'Microsoft.Resources/deployments'
                    apiVersion: '2022-09-01'
                    dependsOn: [
                      '[variables(\'identityReadDeploymentName\')]'
                    ]
                    properties: {
                      mode: 'Incremental'
                      expressionEvaluationOptions: {
                        scope: 'inner'
                      }
                      parameters: commonInstallParameterValues
                      template: {
                        '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        contentVersion: '1.0.0.0'
                        parameters: commonInstallTemplateParameters
                        variables: identityMergeVariables
                        resources: [
                          vmssIdentityWrite
                          {
                            condition: '[variables(\'installExtension\')]'
                            name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                            type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
                            location: '[parameters(\'location\')]'
                            apiVersion: '2021-07-01'
                            dependsOn: [
                              '[parameters(\'resourceName\')]'
                            ]
                            properties: {
                              publisher: 'Crowdstrike.Falcon'
                              type: 'TestFalconSensorLinux'
                              typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                              autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                              settings: {
                                azure_vault_name: '[parameters(\'azureVaultName\')]'
                                azure_managed_identity_client_id: '[parameters(\'azureManagedIdentityClientId\')]'
                                cloud: '[parameters(\'cloud\')]'
                                member_cid: '[parameters(\'memberCid\')]'
                                sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                                disable_proxy: '[parameters(\'disableProxy\')]'
                                proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                                proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                                tags: '[parameters(\'tags\')]'
                              }
                              protectedSettings: {
                                client_id: '[parameters(\'clientId\')]'
                                client_secret: '[parameters(\'clientSecret\')]'
                                access_token: '[parameters(\'accessToken\')]'
                                provisioning_token: '[parameters(\'provisioningToken\')]'
                              }
                            }
                          }
                        ]
                        outputs: identitySkipOutputs
                      }
                    }
                  }
                ]
              }
              parameters: commonTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Linux VM policy assignment at subscription level
resource linuxVmPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: 'CS-Test-Linux-VM-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxVmPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux VMs (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Linux VMs in the subscription'
    parameters: commonLinuxAssignmentParameters
  }
}

// Create Linux VMSS policy assignment at subscription level
resource linuxVmssPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: 'CS-Test-Linux-VMSS-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxVmssPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux VMSS (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Linux VMSS in the subscription'
    parameters: commonLinuxAssignmentParameters
  }
}

// Create Windows VM policy definition
resource windowsVmPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: '${windowsPolicyDefinitionName}-VM'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows VMs'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Windows VMs if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: union(commonParameters, windowsSpecificParameters)
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/osProfile.windowsConfiguration'
            exists: 'true'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/virtualMachineScaleSet.id'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'TestFalconSensorWindows'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: windowsTemplateParameters
                variables: remediationDeploymentNames
                resources: [
                  vmIdentityReadDeployment
                  {
                    name: '[variables(\'falconInstallDeploymentName\')]'
                    type: 'Microsoft.Resources/deployments'
                    apiVersion: '2022-09-01'
                    dependsOn: [
                      '[variables(\'identityReadDeploymentName\')]'
                    ]
                    properties: {
                      mode: 'Incremental'
                      expressionEvaluationOptions: {
                        scope: 'inner'
                      }
                      parameters: windowsInstallParameterValues
                      template: {
                        '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        contentVersion: '1.0.0.0'
                        parameters: windowsInstallTemplateParameters
                        variables: identityMergeVariables
                        resources: [
                          vmIdentityWrite
                          {
                            condition: '[variables(\'installExtension\')]'
                            name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                            type: 'Microsoft.Compute/virtualMachines/extensions'
                            location: '[parameters(\'location\')]'
                            apiVersion: '2021-07-01'
                            dependsOn: [
                              '[parameters(\'resourceName\')]'
                            ]
                            properties: {
                              publisher: 'Crowdstrike.Falcon'
                              type: 'TestFalconSensorWindows'
                              typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                              autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                              settings: {
                                azure_vault_name: '[parameters(\'azureVaultName\')]'
                                azure_managed_identity_client_id: '[parameters(\'azureManagedIdentityClientId\')]'
                                cloud: '[parameters(\'cloud\')]'
                                member_cid: '[parameters(\'memberCid\')]'
                                sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                                disable_proxy: '[parameters(\'disableProxy\')]'
                                proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                                proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                                tags: '[parameters(\'tags\')]'
                                pac_url: '[parameters(\'pacUrl\')]'
                                disable_provisioning_wait: '[parameters(\'disableProvisioningWait\')]'
                                disable_start: '[parameters(\'disableStart\')]'
                                provisioning_wait_time: '[parameters(\'provisioningWaitTime\')]'
                                vdi: '[parameters(\'vdi\')]'
                              }
                              protectedSettings: {
                                client_id: '[parameters(\'clientId\')]'
                                client_secret: '[parameters(\'clientSecret\')]'
                                access_token: '[parameters(\'accessToken\')]'
                                provisioning_token: '[parameters(\'provisioningToken\')]'
                              }
                            }
                          }
                        ]
                        outputs: identitySkipOutputs
                      }
                    }
                  }
                ]
              }
              parameters: windowsTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Windows VMSS policy definition
resource windowsVmssPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: '${windowsPolicyDefinitionName}-VMSS'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows VMSS'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Windows Virtual Machine Scale Sets if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: union(commonParameters, windowsSpecificParameters)
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachineScaleSets'
          }
          {
            field: 'Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.osProfile.windowsConfiguration'
            exists: 'true'
          }
          {
            field: 'tags[\'aks-managed-poolName\']'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/type'
                equals: 'TestFalconSensorWindows'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: windowsTemplateParameters
                variables: remediationDeploymentNames
                resources: [
                  vmssIdentityReadDeployment
                  {
                    name: '[variables(\'falconInstallDeploymentName\')]'
                    type: 'Microsoft.Resources/deployments'
                    apiVersion: '2022-09-01'
                    dependsOn: [
                      '[variables(\'identityReadDeploymentName\')]'
                    ]
                    properties: {
                      mode: 'Incremental'
                      expressionEvaluationOptions: {
                        scope: 'inner'
                      }
                      parameters: windowsInstallParameterValues
                      template: {
                        '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                        contentVersion: '1.0.0.0'
                        parameters: windowsInstallTemplateParameters
                        variables: identityMergeVariables
                        resources: [
                          vmssIdentityWrite
                          {
                            condition: '[variables(\'installExtension\')]'
                            name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                            type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
                            location: '[parameters(\'location\')]'
                            apiVersion: '2021-07-01'
                            dependsOn: [
                              '[parameters(\'resourceName\')]'
                            ]
                            properties: {
                              publisher: 'Crowdstrike.Falcon'
                              type: 'TestFalconSensorWindows'
                              typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                              autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                              settings: {
                                azure_vault_name: '[parameters(\'azureVaultName\')]'
                                azure_managed_identity_client_id: '[parameters(\'azureManagedIdentityClientId\')]'
                                cloud: '[parameters(\'cloud\')]'
                                member_cid: '[parameters(\'memberCid\')]'
                                sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                                disable_proxy: '[parameters(\'disableProxy\')]'
                                proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                                proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                                tags: '[parameters(\'tags\')]'
                                pac_url: '[parameters(\'pacUrl\')]'
                                disable_provisioning_wait: '[parameters(\'disableProvisioningWait\')]'
                                disable_start: '[parameters(\'disableStart\')]'
                                provisioning_wait_time: '[parameters(\'provisioningWaitTime\')]'
                                vdi: '[parameters(\'vdi\')]'
                              }
                              protectedSettings: {
                                client_id: '[parameters(\'clientId\')]'
                                client_secret: '[parameters(\'clientSecret\')]'
                                access_token: '[parameters(\'accessToken\')]'
                                provisioning_token: '[parameters(\'provisioningToken\')]'
                              }
                            }
                          }
                        ]
                        outputs: identitySkipOutputs
                      }
                    }
                  }
                ]
              }
              parameters: windowsTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Windows VM policy assignment at subscription level
resource windowsVmPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: 'CS-Test-Windows-VM-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsVmPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows VMs (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Windows VMs in the subscription'
    parameters: commonWindowsAssignmentParameters
  }
}

// Create Windows VMSS policy assignment at subscription level
resource windowsVmssPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: 'CS-Test-Windows-VMSS-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsVmssPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows VMSS (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Windows VMSS in the subscription'
    parameters: commonWindowsAssignmentParameters
  }
}

// Create role assignments for the policies' managed identities (at subscription scope)
resource linuxVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmPolicyAssignment.id, vmRoleDefinitionId, subscription().id, 'TestLinuxVM')
  properties: {
    principalId: linuxVmPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource linuxVmssContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmssPolicyAssignment.id, vmRoleDefinitionId, subscription().id, 'TestLinuxVMSS')
  properties: {
    principalId: linuxVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmPolicyAssignment.id, vmRoleDefinitionId, subscription().id, 'TestWindowsVM')
  properties: {
    principalId: windowsVmPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmssContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmssPolicyAssignment.id, vmRoleDefinitionId, subscription().id, 'TestWindowsVMSS')
  properties: {
    principalId: windowsVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

// Managed Identity Operator role assignments for VM policies (required for identity attachment)
resource linuxVmMioRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && !empty(azureManagedIdentityResourceId) && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmPolicyAssignment.id, managedIdentityOperatorRoleId, subscription().id, 'TestLinuxVM-MIO')
  properties: {
    principalId: linuxVmPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmMioRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && !empty(azureManagedIdentityResourceId) && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmPolicyAssignment.id, managedIdentityOperatorRoleId, subscription().id, 'TestWindowsVM-MIO')
  properties: {
    principalId: windowsVmPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource linuxVmssMioRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && !empty(azureManagedIdentityResourceId) && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmssPolicyAssignment.id, managedIdentityOperatorRoleId, subscription().id, 'TestLinuxVMSS-MIO')
  properties: {
    principalId: linuxVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmssMioRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && !empty(azureManagedIdentityResourceId) && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmssPolicyAssignment.id, managedIdentityOperatorRoleId, subscription().id, 'TestWindowsVMSS-MIO')
  properties: {
    principalId: windowsVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ──────────────────────────────────────────────────
// Azure Arc-connected server policy definitions
// ──────────────────────────────────────────────────

// Create Linux Arc policy definition
resource linuxArcPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: '${linuxPolicyDefinitionName}-Arc'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux Arc-connected servers'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Linux Azure Arc-connected servers if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: commonParameters
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.HybridCompute/machines'
          }
          {
            field: 'Microsoft.HybridCompute/machines/osName'
            equals: 'linux'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.HybridCompute/machines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.HybridCompute/machines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/type'
                equals: 'TestFalconSensorLinux'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', arcRoleDefinitionId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: commonTemplateParameters
                resources: [
                  {
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                    type: 'Microsoft.HybridCompute/machines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2024-07-10'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'TestFalconSensorLinux'
                      typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                      autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                      settings: {
                        azure_vault_name: '[parameters(\'azureVaultName\')]'
                        cloud: '[parameters(\'cloud\')]'
                        member_cid: '[parameters(\'memberCid\')]'
                        sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                        disable_proxy: '[parameters(\'disableProxy\')]'
                        proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                        proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                        tags: '[parameters(\'tags\')]'
                      }
                      protectedSettings: {
                        client_id: '[parameters(\'clientId\')]'
                        client_secret: '[parameters(\'clientSecret\')]'
                        access_token: '[parameters(\'accessToken\')]'
                        provisioning_token: '[parameters(\'provisioningToken\')]'
                      }
                    }
                  }
                ]
              }
              parameters: commonTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Windows Arc policy definition
resource windowsArcPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: '${windowsPolicyDefinitionName}-Arc'
  properties: {
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows Arc-connected servers'
    description: 'Test policy - deploys CrowdStrike Falcon test extension on Windows Azure Arc-connected servers if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: policyMetadata
    parameters: union(commonParameters, windowsSpecificParameters)
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.HybridCompute/machines'
          }
          {
            field: 'Microsoft.HybridCompute/machines/osName'
            equals: 'windows'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.HybridCompute/machines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.HybridCompute/machines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/type'
                equals: 'TestFalconSensorWindows'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            subscriptionResourceId('Microsoft.Authorization/roleDefinitions', arcRoleDefinitionId)
          ]
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: windowsTemplateParameters
                resources: [
                  {
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeTestFalconSensor\')]'
                    type: 'Microsoft.HybridCompute/machines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2024-07-10'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'TestFalconSensorWindows'
                      typeHandlerVersion: '[parameters(\'extensionSettings\').handlerVersion]'
                      autoUpgradeMinorVersion: '[parameters(\'extensionSettings\').autoUpgradeMinorVersion]'
                      settings: {
                        azure_vault_name: '[parameters(\'azureVaultName\')]'
                        cloud: '[parameters(\'cloud\')]'
                        member_cid: '[parameters(\'memberCid\')]'
                        sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                        disable_proxy: '[parameters(\'disableProxy\')]'
                        proxy_host: '[parameters(\'proxySettings\').proxyHost]'
                        proxy_port: '[parameters(\'proxySettings\').proxyPort]'
                        tags: '[parameters(\'tags\')]'
                        pac_url: '[parameters(\'pacUrl\')]'
                        disable_provisioning_wait: '[parameters(\'disableProvisioningWait\')]'
                        disable_start: '[parameters(\'disableStart\')]'
                        provisioning_wait_time: '[parameters(\'provisioningWaitTime\')]'
                        vdi: '[parameters(\'vdi\')]'
                      }
                      protectedSettings: {
                        client_id: '[parameters(\'clientId\')]'
                        client_secret: '[parameters(\'clientSecret\')]'
                        access_token: '[parameters(\'accessToken\')]'
                        provisioning_token: '[parameters(\'provisioningToken\')]'
                      }
                    }
                  }
                ]
              }
              parameters: windowsTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Linux Arc policy assignment at subscription level
resource linuxArcPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: 'CS-Test-Linux-Arc-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxArcPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Linux Arc-connected servers (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Linux Arc-connected servers in the subscription'
    parameters: commonLinuxAssignmentParameters
  }
}

// Create Windows Arc policy assignment at subscription level
resource windowsArcPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: 'CS-Test-Windows-Arc-${take(subscription().subscriptionId, 8)}'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsArcPolicyDefinition.id
    displayName: 'Test - Deploy CrowdStrike Falcon sensor on Windows Arc-connected servers (Subscription)'
    description: 'Test policy - ensures CrowdStrike Falcon test extension is installed on all Windows Arc-connected servers in the subscription'
    parameters: commonWindowsAssignmentParameters
  }
}

// Create role assignments for Arc policies' managed identities
resource linuxArcRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxArcPolicyAssignment.id, arcRoleDefinitionId, subscription().id, 'TestLinuxArc')
  properties: {
    principalId: linuxArcPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', arcRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsArcRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsArcPolicyAssignment.id, arcRoleDefinitionId, subscription().id, 'TestWindowsArc')
  properties: {
    principalId: windowsArcPolicyAssignment!.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', arcRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

// ──────────────────────────────────────────────────
// Key Vault reference access
// ──────────────────────────────────────────────────

// Least-privilege role that lets ARM resolve Key Vault references during policy remediation.
// Key Vault Contributor also grants this action, but can modify vault access configuration.
resource keyVaultDeployRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (createRoleAssignments && useKeyVaultReferences) {
  name: guid(subscription().id, 'CS-Falcon-Test-KeyVault-Deploy')
  properties: {
    roleName: 'CrowdStrike Falcon Test Key Vault Template Deploy (${subscription().subscriptionId})'
    description: 'Allows Azure Resource Manager to resolve Key Vault references during CrowdStrike Falcon test policy remediation'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.KeyVault/vaults/deploy/action'
        ]
        notActions: []
      }
    ]
    assignableScopes: union([subscription().id], ['/subscriptions/${keyVaultIdParts[2]}'])
  }
}

var policyAssignmentPrincipalIds = concat(
  (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? [linuxVmPolicyAssignment!.identity.principalId, linuxVmssPolicyAssignment!.identity.principalId] : [],
  (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? [windowsVmPolicyAssignment!.identity.principalId, windowsVmssPolicyAssignment!.identity.principalId] : [],
  (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) ? [linuxArcPolicyAssignment!.identity.principalId] : [],
  (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) ? [windowsArcPolicyAssignment!.identity.principalId] : []
)

module keyVaultDeployAccess '../policy/keyvault-deploy-access.bicep' = if (createRoleAssignments && useKeyVaultReferences) {
  name: 'CS-Falcon-Test-KeyVault-Deploy-Access'
  scope: resourceGroup(keyVaultIdParts[2], keyVaultIdParts[4])
  params: {
    vaultName: keyVaultIdParts[8]
    roleDefinitionId: subscriptionResourceId(keyVaultIdParts[2], 'Microsoft.Authorization/roleDefinitions', keyVaultDeployRole.name)
    principalIds: policyAssignmentPrincipalIds
  }
}

// Outputs
output linuxVmPolicyDefinitionId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmPolicyDefinition.id : ''
output linuxVmssPolicyDefinitionId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmssPolicyDefinition.id : ''
output windowsVmPolicyDefinitionId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmPolicyDefinition.id : ''
output windowsVmssPolicyDefinitionId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmssPolicyDefinition.id : ''
output linuxVmPolicyAssignmentId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmPolicyAssignment.id : ''
output linuxVmssPolicyAssignmentId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmssPolicyAssignment.id : ''
output windowsVmPolicyAssignmentId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmPolicyAssignment.id : ''
output windowsVmssPolicyAssignmentId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmssPolicyAssignment.id : ''
output linuxArcPolicyDefinitionId string = (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) ? linuxArcPolicyDefinition.id : ''
output windowsArcPolicyDefinitionId string = (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) ? windowsArcPolicyDefinition.id : ''
output linuxArcPolicyAssignmentId string = (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) ? linuxArcPolicyAssignment.id : ''
output windowsArcPolicyAssignmentId string = (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) ? windowsArcPolicyAssignment.id : ''
output linuxArcPolicyPrincipalId string = (deployToArc && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) ? linuxArcPolicyAssignment!.identity.principalId : ''
output windowsArcPolicyPrincipalId string = (deployToArc && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) ? windowsArcPolicyAssignment!.identity.principalId : ''
output linuxVmPolicyPrincipalId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmPolicyAssignment!.identity.principalId : ''
output linuxVmssPolicyPrincipalId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmssPolicyAssignment!.identity.principalId : ''
output windowsVmPolicyPrincipalId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmPolicyAssignment!.identity.principalId : ''
output windowsVmssPolicyPrincipalId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmssPolicyAssignment!.identity.principalId : ''
output subscriptionId string = subscription().subscriptionId
output subscriptionName string = subscription().displayName
