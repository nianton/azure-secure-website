param location string = resourceGroup().location
param project string = 'secwebapp'
param environment string = 'dev'

@description('Container to move the files from the scheduled run')
param archiveContainerName string = 'archive'

@description('The function application repository to be deployed -change if forked')
param functionAppRepoUrl string = 'https://github.com/nianton/azstorage-to-s3'

@description('The function application repository branch to be deployed')
param functionAppRepoBranch string = 'main'

@allowed([
  'standard'
  'premium'
])
@description('Azure Key Vault SKU')
param keyVaultSku string = 'premium'

@allowed([
  'Y1'
  'EP1'
  'EP2'
  'EP3'
])
@description('Azure Function plan, Y1: Consumption, EPx: Elastic Premium')
param azureFunctionPlanSkuName string = 'EP1'

@secure()
@description('Jumpbox vm password')
param jumpboxPassword string

// Resource names - establish naming convention
var resourcePrefix = '${project}-${environment}'
var resourceNames = {
  vnet: '${resourcePrefix}-vnet'
  snet1: '${resourcePrefix}-snet-01'
  snet2: '${resourcePrefix}-snet-02'
  snet3: '${resourcePrefix}-snet-03'
  funcApp: '${resourcePrefix}-func'
  keyVault: '${resourcePrefix}-kv'
  serviceBusNamespace: '${resourcePrefix}-sbns'
  dataStorage: 's${toLower(replace(resourcePrefix, '-', ''))}data'
  jumpboxVm: '${substring(resourcePrefix, 0, 10)}-jbvm'
}

// Vnet configuration
var virtualNetwork_CIDR = '10.200.0.0/16'
var subnet1_CIDR = '10.200.1.0/24'
var subnet2_CIDR = '10.200.2.0/24'
var subnet3_CIDR = '10.200.3.0/24'

var secretNames = {
  dataStorageConnectionString: 'dataStorageConnectionString'
  serviceBusConnectionString: 'serviceBusConnectionstring'
  mySqlConnectionString: 'mySqlConnectionString'
}

// Default tags to be added to all resources
var defaultTags = {
  environment: environment
  project: project
}

// Containers for data storage account
var containerNames = [
  archiveContainerName
]

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: resourceNames.vnet
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetwork_CIDR
      ]
    }
    subnets: [
      {
        name: resourceNames.snet1
        properties: {
          addressPrefix: subnet1_CIDR
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.snet2
        properties: {
          addressPrefix: subnet2_CIDR
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: resourceNames.snet3
        properties: {
          addressPrefix: subnet3_CIDR
        }
      }
    ]
  }
  tags: defaultTags
}

// Storage Account containing the data
module dataStorage './modules/storage.module.bicep' = {
  name: 'dataStorage'
  params: {
    name: resourceNames.dataStorage
    location: location
    tags: defaultTags
  }
}

module serviceBus 'modules/servicebus.module.bicep' = {
  name: 'serviceBus'
  params: {
    name: resourceNames.serviceBusNamespace
    location: location
    tags: defaultTags
  }
}

// Blob Containers based on the provided naming
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = [for containerName in containerNames: {
  name: '${resourceNames.dataStorage}/default/${containerName}'
  dependsOn:[
    dataStorage
  ]
}]

// Function Application (with respected Application Insights and Storage Account)
// with the respective configuration, and deployment of the application
module funcApp './modules/functionApp.module.bicep' = {
  name: 'funcApp'
  params: {
    location: location
    name: resourceNames.funcApp
    managedIdentity: true
    tags: defaultTags
    skuName: azureFunctionPlanSkuName
    // funcDeployBranch: functionAppRepoBranch
    // funcDeployRepoUrl: functionAppRepoUrl
    funcAppSettings: [
      {
        name: 'DataStorageConnection'
        value: '@Microsoft.KeyVault(VaultName=${resourceNames.keyVault};SecretName=${secretNames.dataStorageConnectionString})'
      }
      {
        name: 'ServiceBusConnection'
        value: '@Microsoft.KeyVault(VaultName=${resourceNames.keyVault};SecretName=${secretNames.serviceBusConnectionString})'
      }
    ]
  }
}

module mysql 'modules/mysql.module.bicep' = {
  name: 'mysql'
  params: {
    namePrefix: resourcePrefix
    location: location
    tags: defaultTags
    adminLogin: 'dbuser'
    adminPassword: 'Qwertyuiop123!'
    skuName: 'GP_Gen5_2'
    skuTier: 'GeneralPurpose'
    mySQLVersion: '5.7'
  }
}

module keyVault 'modules/keyvault.module.bicep' = {
  name: 'keyVault'
  params: {
    name: resourceNames.keyVault
    location: location    
    skuName: 'premium'
    tags: defaultTags
    accessPolicies: [
      {
        tenantId: funcApp.outputs.identity.tenantId
        objectId: funcApp.outputs.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    secrets:[
      {
        name: secretNames.dataStorageConnectionString
        value: dataStorage.outputs.connectionString
      }
      {
        name: secretNames.serviceBusConnectionString
        value: serviceBus.outputs.connectionString
      }
      {
        name: secretNames.mySqlConnectionString
        value: mysql.outputs.connectionString
      }
    ]
  }
}

module jumpbox 'modules/vmjumpbox.module.bicep' = {
  name: 'jumpbox'
  params: {
    subnetId: vnet.properties.subnets[2].id
    location: location
    name: resourceNames.jumpboxVm
    dnsLabelPrefix: resourceNames.jumpboxVm
    adminPassword: jumpboxPassword
    tags: defaultTags
  }
}

output funcDeployment object = funcApp
output dataStorage object = dataStorage
output keyVault object = {
  id: keyVault.outputs.id
  name: keyVault.outputs.name
}
