param keyVaultName string

@description('Array of name/value pairs')
param secrets array

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = [for secret in secrets: {
  name: '${keyVaultName}/${secret.name}'
  properties: {
    value: secret.value
  }
}]
