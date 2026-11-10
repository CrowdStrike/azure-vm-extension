// Grants policy assignment identities permission to resolve Key Vault references
// (Microsoft.KeyVault/vaults/deploy/action) on a single vault.

param vaultName string
param roleDefinitionId string
param principalIds array

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: vaultName
}

resource keyVaultDeployRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in principalIds: {
  name: guid(vault.id, principalId, roleDefinitionId)
  scope: vault
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
