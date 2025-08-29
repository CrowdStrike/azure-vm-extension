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

@description('Handler version for the CrowdStrike Falcon extension')
param handlerVersion string = '0.0'

@description('Auto upgrade minor version for the CrowdStrike Falcon extension')
param autoUpgradeMinorVersion bool = true

// CrowdStrike Parameters
@secure()
param clientId string = ''
@secure()
param clientSecret string = ''
@secure()
param accessToken string = ''
@secure()
param azureVaultName string = ''
param cloud string = 'autodiscover'
param memberCid string = ''
param sensorUpdatePolicy string = 'platform_default'
param disableProxy bool = false
@secure()
param provisioningToken string = ''
param proxyHost string = ''
param proxyPort string = ''
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

// Create Linux policy definition
resource linuxPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: linuxPolicyDefinitionName
  properties: {
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMs'
    description: 'This policy deploys CrowdStrike Falcon sensor on Linux VMs if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Security'
      version: '1.0.0'
    }
    parameters: {
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
        defaultValue: ''
      }
      azureVaultName: {
        type: 'String'
        metadata: {
          displayName: 'Azure Key Vault Name'
          description: 'Azure Key Vault name containing CrowdStrike credentials'
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
      proxyHost: {
        type: 'String'
        metadata: {
          displayName: 'Proxy Host'
          description: 'Proxy host configuration'
        }
        defaultValue: ''
      }
      proxyPort: {
        type: 'String'
        metadata: {
          displayName: 'Proxy Port'
          description: 'Proxy port configuration'
        }
        defaultValue: ''
      }
      tags: {
        type: 'String'
        metadata: {
          displayName: 'Tags'
          description: 'Comma-separated list of tags'
        }
        defaultValue: ''
      }
      handlerVersion: {
        type: 'String'
        metadata: {
          displayName: 'Handler Version'
          description: 'CrowdStrike Falcon extension handler version'
        }
        defaultValue: '0.0'
      }
      autoUpgradeMinorVersion: {
        type: 'Boolean'
        metadata: {
          displayName: 'Auto Upgrade Minor Version'
          description: 'Auto upgrade minor version for the CrowdStrike Falcon extension'
        }
        defaultValue: true
      }
    }
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
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
          ]
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'FalconSensorLinux'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: { type: 'string' }
                  location: { type: 'string' }
                  clientId: { type: 'securestring' }
                  clientSecret: { type: 'securestring' }
                  accessToken: { type: 'securestring' }
                  azureVaultName: { type: 'securestring' }
                  cloud: { type: 'string' }
                  memberCid: { type: 'string' }
                  sensorUpdatePolicy: { type: 'string' }
                  disableProxy: { type: 'bool' }
                  provisioningToken: { type: 'securestring' }
                  proxyHost: { type: 'string' }
                  proxyPort: { type: 'string' }
                  tags: { type: 'string' }
                  handlerVersion: { type: 'string' }
                  autoUpgradeMinorVersion: { type: 'bool' }
                }
                resources: [
                  {
                    name: '[concat(parameters(\'vmName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorLinux'
                      typeHandlerVersion: '[parameters(\'handlerVersion\')]'
                      autoUpgradeMinorVersion: '[parameters(\'autoUpgradeMinorVersion\')]'
                      settings: {
                        cloud: '[parameters(\'cloud\')]'
                        member_cid: '[parameters(\'memberCid\')]'
                        sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                        disable_proxy: '[parameters(\'disableProxy\')]'
                        proxy_host: '[parameters(\'proxyHost\')]'
                        proxy_port: '[parameters(\'proxyPort\')]'
                        tags: '[parameters(\'tags\')]'
                      }
                      protectedSettings: {
                        client_id: '[parameters(\'clientId\')]'
                        client_secret: '[parameters(\'clientSecret\')]'
                        access_token: '[parameters(\'accessToken\')]'
                        azure_vault_name: '[parameters(\'azureVaultName\')]'
                        provisioning_token: '[parameters(\'provisioningToken\')]'
                      }
                    }
                  }
                ]
              }
              parameters: {
                vmName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
                clientId: {
                  value: '[parameters(\'clientId\')]'
                }
                clientSecret: {
                  value: '[parameters(\'clientSecret\')]'
                }
                accessToken: {
                  value: '[parameters(\'accessToken\')]'
                }
                azureVaultName: {
                  value: '[parameters(\'azureVaultName\')]'
                }
                cloud: {
                  value: '[parameters(\'cloud\')]'
                }
                memberCid: {
                  value: '[parameters(\'memberCid\')]'
                }
                sensorUpdatePolicy: {
                  value: '[parameters(\'sensorUpdatePolicy\')]'
                }
                disableProxy: {
                  value: '[parameters(\'disableProxy\')]'
                }
                provisioningToken: {
                  value: '[parameters(\'provisioningToken\')]'
                }
                proxyHost: {
                  value: '[parameters(\'proxyHost\')]'
                }
                proxyPort: {
                  value: '[parameters(\'proxyPort\')]'
                }
                tags: {
                  value: '[parameters(\'tags\')]'
                }
                handlerVersion: {
                  value: '[parameters(\'handlerVersion\')]'
                }
                autoUpgradeMinorVersion: {
                  value: '[parameters(\'autoUpgradeMinorVersion\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// Create Linux policy assignment at management group level
resource linuxPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'linux' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Linux-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: linuxPolicyDefinition!.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Linux VMs (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Linux VMs in the management group'
    parameters: {
      effect: {
        value: policyEffect
      }
      clientId: {
        value: clientId
      }
      clientSecret: {
        value: clientSecret
      }
      accessToken: {
        value: accessToken
      }
      azureVaultName: {
        value: azureVaultName
      }
      cloud: {
        value: cloud
      }
      memberCid: {
        value: memberCid
      }
      sensorUpdatePolicy: {
        value: sensorUpdatePolicy
      }
      disableProxy: {
        value: disableProxy
      }
      provisioningToken: {
        value: provisioningToken
      }
      proxyHost: {
        value: proxyHost
      }
      proxyPort: {
        value: proxyPort
      }
      tags: {
        value: tags
      }
      handlerVersion: {
        value: handlerVersion
      }
      autoUpgradeMinorVersion: {
        value: autoUpgradeMinorVersion
      }
    }
  }
}

// Create Windows policy definition
resource windowsPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: windowsPolicyDefinitionName
  properties: {
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMs'
    description: 'This policy deploys CrowdStrike Falcon sensor on Windows VMs if not installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Security'
      version: '1.0.0'
    }
    parameters: {
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
        defaultValue: ''
      }
      azureVaultName: {
        type: 'String'
        metadata: {
          displayName: 'Azure Key Vault Name'
          description: 'Azure Key Vault name containing CrowdStrike credentials'
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
      proxyHost: {
        type: 'String'
        metadata: {
          displayName: 'Proxy Host'
          description: 'Proxy host configuration'
        }
        defaultValue: ''
      }
      proxyPort: {
        type: 'String'
        metadata: {
          displayName: 'Proxy Port'
          description: 'Proxy port configuration'
        }
        defaultValue: ''
      }
      tags: {
        type: 'String'
        metadata: {
          displayName: 'Tags'
          description: 'Comma-separated list of tags'
        }
        defaultValue: ''
      }
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
      handlerVersion: {
        type: 'String'
        metadata: {
          displayName: 'Handler Version'
          description: 'CrowdStrike Falcon extension handler version'
        }
        defaultValue: '0.0'
      }
      autoUpgradeMinorVersion: {
        type: 'Boolean'
        metadata: {
          displayName: 'Auto Upgrade Minor Version'
          description: 'Auto upgrade minor version for the CrowdStrike Falcon extension'
        }
        defaultValue: true
      }
    }
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
          roleDefinitionIds: [
            tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
          ]
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'FalconSensorWindows'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Crowdstrike.Falcon'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: { type: 'string' }
                  location: { type: 'string' }
                  clientId: { type: 'securestring' }
                  clientSecret: { type: 'securestring' }
                  accessToken: { type: 'securestring' }
                  azureVaultName: { type: 'securestring' }
                  cloud: { type: 'string' }
                  memberCid: { type: 'string' }
                  sensorUpdatePolicy: { type: 'string' }
                  disableProxy: { type: 'bool' }
                  provisioningToken: { type: 'securestring' }
                  proxyHost: { type: 'string' }
                  proxyPort: { type: 'string' }
                  tags: { type: 'string' }
                  pacUrl: { type: 'string' }
                  disableProvisioningWait: { type: 'bool' }
                  disableStart: { type: 'bool' }
                  provisioningWaitTime: { type: 'string' }
                  vdi: { type: 'bool' }
                  handlerVersion: { type: 'string' }
                  autoUpgradeMinorVersion: { type: 'bool' }
                }
                resources: [
                  {
                    name: '[concat(parameters(\'vmName\'), \'/CrowdStrikeFalconSensor\')]'
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2021-07-01'
                    properties: {
                      publisher: 'Crowdstrike.Falcon'
                      type: 'FalconSensorWindows'
                      typeHandlerVersion: '[parameters(\'handlerVersion\')]'
                      autoUpgradeMinorVersion: '[parameters(\'autoUpgradeMinorVersion\')]'
                      settings: {
                        cloud: '[parameters(\'cloud\')]'
                        member_cid: '[parameters(\'memberCid\')]'
                        sensor_update_policy: '[parameters(\'sensorUpdatePolicy\')]'
                        disable_proxy: '[parameters(\'disableProxy\')]'
                        proxy_host: '[parameters(\'proxyHost\')]'
                        proxy_port: '[parameters(\'proxyPort\')]'
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
                        azure_vault_name: '[parameters(\'azureVaultName\')]'
                        provisioning_token: '[parameters(\'provisioningToken\')]'
                      }
                    }
                  }
                ]
              }
              parameters: {
                vmName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
                clientId: {
                  value: '[parameters(\'clientId\')]'
                }
                clientSecret: {
                  value: '[parameters(\'clientSecret\')]'
                }
                accessToken: {
                  value: '[parameters(\'accessToken\')]'
                }
                azureVaultName: {
                  value: '[parameters(\'azureVaultName\')]'
                }
                cloud: {
                  value: '[parameters(\'cloud\')]'
                }
                memberCid: {
                  value: '[parameters(\'memberCid\')]'
                }
                sensorUpdatePolicy: {
                  value: '[parameters(\'sensorUpdatePolicy\')]'
                }
                disableProxy: {
                  value: '[parameters(\'disableProxy\')]'
                }
                provisioningToken: {
                  value: '[parameters(\'provisioningToken\')]'
                }
                proxyHost: {
                  value: '[parameters(\'proxyHost\')]'
                }
                proxyPort: {
                  value: '[parameters(\'proxyPort\')]'
                }
                tags: {
                  value: '[parameters(\'tags\')]'
                }
                pacUrl: {
                  value: '[parameters(\'pacUrl\')]'
                }
                disableProvisioningWait: {
                  value: '[parameters(\'disableProvisioningWait\')]'
                }
                disableStart: {
                  value: '[parameters(\'disableStart\')]'
                }
                provisioningWaitTime: {
                  value: '[parameters(\'provisioningWaitTime\')]'
                }
                vdi: {
                  value: '[parameters(\'vdi\')]'
                }
                handlerVersion: {
                  value: '[parameters(\'handlerVersion\')]'
                }
                autoUpgradeMinorVersion: {
                  value: '[parameters(\'autoUpgradeMinorVersion\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// Create Windows policy assignment at management group level
resource windowsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = if (operatingSystemLower == 'windows' || operatingSystemLower == 'both') {
  name: 'CS-Falcon-Win-MG'
  location: deployment().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: windowsPolicyDefinition!.id
    displayName: 'Deploy CrowdStrike Falcon sensor on Windows VMs (Management Group)'
    description: 'This policy ensures CrowdStrike Falcon sensor is installed on all Windows VMs in the management group'
    parameters: {
      effect: {
        value: policyEffect
      }
      clientId: {
        value: clientId
      }
      clientSecret: {
        value: clientSecret
      }
      accessToken: {
        value: accessToken
      }
      azureVaultName: {
        value: azureVaultName
      }
      cloud: {
        value: cloud
      }
      memberCid: {
        value: memberCid
      }
      sensorUpdatePolicy: {
        value: sensorUpdatePolicy
      }
      disableProxy: {
        value: disableProxy
      }
      provisioningToken: {
        value: provisioningToken
      }
      proxyHost: {
        value: proxyHost
      }
      proxyPort: {
        value: proxyPort
      }
      tags: {
        value: tags
      }
      pacUrl: {
        value: pacUrl
      }
      disableProvisioningWait: {
        value: disableProvisioningWait
      }
      disableStart: {
        value: disableStart
      }
      provisioningWaitTime: {
        value: provisioningWaitTime
      }
      vdi: {
        value: vdi
      }
      handlerVersion: {
        value: handlerVersion
      }
      autoUpgradeMinorVersion: {
        value: autoUpgradeMinorVersion
      }
    }
  }
}

// Create role assignments for the policies' managed identities (at management group scope)
resource linuxVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'linux' || operatingSystemLower == 'both')) {
  name: guid(linuxPolicyAssignment!.id, vmRoleDefinitionId, managementGroup().id, 'Linux')
  properties: {
    principalId: linuxPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

resource windowsVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRoleAssignments && (operatingSystemLower == 'windows' || operatingSystemLower == 'both')) {
  name: guid(windowsPolicyAssignment!.id, vmRoleDefinitionId, managementGroup().id, 'Windows')
  properties: {
    principalId: windowsPolicyAssignment!.identity.principalId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output linuxPolicyDefinitionId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxPolicyDefinition!.id : ''
output windowsPolicyDefinitionId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsPolicyDefinition!.id : ''
output linuxPolicyAssignmentId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxPolicyAssignment!.id : ''
output windowsPolicyAssignmentId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsPolicyAssignment!.id : ''
output linuxPolicyPrincipalId string = (operatingSystemLower == 'linux' || operatingSystemLower == 'both') ? linuxPolicyAssignment!.identity.principalId : ''
output windowsPolicyPrincipalId string = (operatingSystemLower == 'windows' || operatingSystemLower == 'both') ? windowsPolicyAssignment!.identity.principalId : ''
output managementGroupId string = managementGroup().id
output managementGroupName string = managementGroup().name
