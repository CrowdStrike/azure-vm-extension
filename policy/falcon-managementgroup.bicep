targetScope = 'managementGroup'

@description('Operating systems to deploy policies for')
@allowed([
  'linux'
  'windows'
  'both'
])
param operatingSystem string = 'both'

@description('Policy definition name prefix')
param policyDefinitionNamePrefix string = 'CS-Falcon-Policy'

@description('Effect for the policy assignment (DeployIfNotExists, AuditIfNotExists, Disabled)')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param policyEffect string = 'DeployIfNotExists'

@description('Create role assignments for policy managed identities (requires Owner or User Access Administrator role)')
param createRoleAssignments bool = true

@description('Extension configuration settings')
param extensionSettings object = {
  handlerVersion: '0.0'
  autoUpgradeMinorVersion: true
}

// CrowdStrike Parameters
@secure()
param clientId string = ''
@secure()
param clientSecret string = ''
@secure()
param accessToken string = ''
param azureVaultName string = ''
param cloud string = 'autodiscover'
param memberCid string = ''
param sensorUpdatePolicy string = 'platform_default'
param disableProxy bool = false
@secure()
param provisioningToken string = ''
param azureManagedIdentityClientId string = ''
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
var vmRoleDefinitionId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var linuxPolicyDefinitionName = '${policyDefinitionNamePrefix}-Linux'
var windowsPolicyDefinitionName = '${policyDefinitionNamePrefix}-Windows'

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
  clientId: {
    type: 'String'
    metadata: {
      displayName: 'CrowdStrike Client ID'
      description: 'CrowdStrike API Client ID'
    }
  }
  clientSecret: {
    type: 'String'
    metadata: {
      displayName: 'CrowdStrike Client Secret'
      description: 'CrowdStrike API Client Secret'
    }
  }
  accessToken: {
    type: 'String'
    metadata: {
      displayName: 'CrowdStrike Access Token'
      description: 'CrowdStrike API Access Token'
    }
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
  provisioningToken: {
    type: 'String'
    metadata: {
      displayName: 'Provisioning Token'
      description: 'CrowdStrike Provisioning Token'
    }
    defaultValue: ''
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

var commonTemplateParameterValues = {
  resourceName: { value: '[field(\'name\')]' }
  location: { value: '[field(\'location\')]' }
  clientId: { value: '[parameters(\'clientId\')]' }
  clientSecret: { value: '[parameters(\'clientSecret\')]' }
  accessToken: { value: '[parameters(\'accessToken\')]' }
  azureVaultName: { value: '[parameters(\'azureVaultName\')]' }
  azureManagedIdentityClientId: { value: '[parameters(\'azureManagedIdentityClientId\')]' }
  cloud: { value: '[parameters(\'cloud\')]' }
  memberCid: { value: '[parameters(\'memberCid\')]' }
  sensorUpdatePolicy: { value: '[parameters(\'sensorUpdatePolicy\')]' }
  disableProxy: { value: '[parameters(\'disableProxy\')]' }
  provisioningToken: { value: '[parameters(\'provisioningToken\')]' }
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

var commonLinuxAssignmentParameters = {
  effect: { value: policyEffect }
  clientId: { value: clientId }
  clientSecret: { value: clientSecret }
  accessToken: { value: accessToken }
  azureVaultName: { value: azureVaultName }
  azureManagedIdentityClientId: { value: azureManagedIdentityClientId }
  cloud: { value: cloud }
  memberCid: { value: memberCid }
  sensorUpdatePolicy: { value: sensorUpdatePolicy }
  disableProxy: { value: disableProxy }
  provisioningToken: { value: provisioningToken }
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
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMs'
    description: 'This policy deploys CrowdStrike Falcon sensor on Linux VMs if not installed'
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
                equals: 'FalconSensorLinux'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
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
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorLinux'
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
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMSS'
    description: 'This policy deploys CrowdStrike Falcon sensor on Linux Virtual Machine Scale Sets if not installed'
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
                equals: 'FalconSensorLinux'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
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
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorLinux'
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
              }
              parameters: commonTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Linux VM policy assignment at management group level
resource linuxVmPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Linux-VM-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxVmPolicyDefinition.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMs (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Linux VMs in the management group'
    parameters: commonLinuxAssignmentParameters
  }
}

// Create Linux VMSS policy assignment at management group level
resource linuxVmssPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Linux-VMSS-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxVmssPolicyDefinition.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMSS (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Linux VMSS in the management group'
    parameters: commonLinuxAssignmentParameters
  }
}

// Create Windows VM policy definition
resource windowsVmPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: '${windowsPolicyDefinitionName}-VM'
  properties: {
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMs'
    description: 'This policy deploys CrowdStrike Falcon sensor on Windows VMs if not installed'
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
                equals: 'FalconSensorWindows'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
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
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorWindows'
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
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMSS'
    description: 'This policy deploys CrowdStrike Falcon sensor on Windows Virtual Machine Scale Sets if not installed'
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
                equals: 'FalconSensorWindows'
              }
              {
                field: 'Microsoft.Compute/virtualMachineScaleSets/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
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
                    name: '[concat(parameters(\'resourceName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachineScaleSets/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorWindows'
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
              }
              parameters: windowsTemplateParameterValues
            }
          }
        }
      }
    }
  }
}

// Create Windows VM policy assignment at management group level
resource windowsVmPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Windows-VM-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsVmPolicyDefinition.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMs (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Windows VMs in the management group'
    parameters: commonWindowsAssignmentParameters
  }
}

// Create Windows VMSS policy assignment at management group level
resource windowsVmssPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Windows-VMSS-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsVmssPolicyDefinition.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMSS (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Windows VMSS in the management group'
    parameters: commonWindowsAssignmentParameters
  }
}

// Create role assignments for the policies' managed identities (at management group scope)
resource linuxVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmPolicyAssignment.id, vmRoleDefinitionId, managementGroup().id, 'LinuxVM')
  properties: {
    principalId: linuxVmPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource linuxVmssContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxVmssPolicyAssignment.id, vmRoleDefinitionId, managementGroup().id, 'LinuxVMSS')
  properties: {
    principalId: linuxVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmPolicyAssignment.id, vmRoleDefinitionId, managementGroup().id, 'WindowsVM')
  properties: {
    principalId: windowsVmPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmssContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsVmssPolicyAssignment.id, vmRoleDefinitionId, managementGroup().id, 'WindowsVMSS')
  properties: {
    principalId: windowsVmssPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
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
output linuxVmPolicyPrincipalId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmPolicyAssignment!.identity.principalId : ''
output linuxVmssPolicyPrincipalId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxVmssPolicyAssignment!.identity.principalId : ''
output windowsVmPolicyPrincipalId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmPolicyAssignment!.identity.principalId : ''
output windowsVmssPolicyPrincipalId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsVmssPolicyAssignment!.identity.principalId : ''
output managementGroupId string = managementGroup().id
output managementGroupName string = managementGroup().name
