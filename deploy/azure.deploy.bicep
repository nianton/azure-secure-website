param location string = resourceGroup().location
param project string = 'secweb3'
param environment string = 'dev'
param naming object

@description('Container to move the files from the scheduled run')
param archiveContainerName string = 'archive'

@description('The function application repository to be deployed -change if forked')
param functionAppRepoUrl string = 'https://github.com/nianton/azstorage-to-s3'

@description('The function application repository branch to be deployed')
param functionAppRepoBranch string = 'main'

@description('Whether to use private endpoints to expose the Azure Functions and WebApp')
param usePrivateLinks bool = true

@allowed([
  'standard'
  'premium'
])
@description('Azure Key Vault SKU')
param keyVaultSku string = 'premium'

@description('Whether to include a Bastion to access the jumphost the deployment')
param includeBastion bool = true

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
var resourceNames = {
  vnet: naming.virtualNetwork.name
  defaultSnet: '${naming.subnet.name}-01'
  appSnet: '${naming.subnet.name}-02'
  devSnet: '${naming.subnet.name}-03'
  integratedSnet: '${naming.subnet.name}-04'
  funcApp: naming.functionApp.name
  webApp: naming.appService.name
  keyVault: naming.keyVault.name
  serviceBusNamespace: naming.serviceBusNamespace.name
  dataStorage: '${naming.storageAccount.name}data'
  jumpboxVm: naming.virtualMachine.name
  bastion: naming.bastionHost.name
  mysqlServer: naming.mysqlServer.name
  mysqlDatabase: naming.mysqlDatabase.name
}

// Vnet configuration
var virtualNetwork_CIDR = '10.200.1.0/24'
var subnet1_CIDR = '10.200.1.0/26'
var subnet2_CIDR = '10.200.1.64/26'
var subnet3_CIDR = '10.200.1.128/26'
var subnet4_CIDR = '10.200.1.192/27'
var subnet5_CIDR = '10.200.1.224/27'

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

module vnet 'modules/vnet.module.bicep' = {
  name: 'vnet-${resourceNames.vnet}'
  params: {
    name: resourceNames.vnet
    addressPrefix: virtualNetwork_CIDR
    includeBastion: true
    location: location
    tags: defaultTags
    defaultSnet: {
      name: resourceNames.defaultSnet
      properties: {
        addressPrefix: subnet1_CIDR
      }
    }
    appSnet: {
      name: resourceNames.appSnet
      properties: {
        addressPrefix: subnet2_CIDR
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }
    devOpsSnet: {
      name: resourceNames.devSnet
      properties: {
        addressPrefix: subnet3_CIDR
      }
    }
    integratedSnet: {
      name: resourceNames.integratedSnet
      properties: {
        addressPrefix: subnet4_CIDR
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
    bastionSnet: {
      properties: {
        addressPrefix: subnet5_CIDR
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }
  }
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
  dependsOn: [
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

module webApp 'modules/webApp.module.bicep' = {
  name: 'webApp'
  params: {
    location: location
    name: resourceNames.webApp
    managedIdentity: true
    tags: defaultTags
    appSettings: [
      {
        name: 'MySqlConnection'
        value: '@Microsoft.KeyVault(VaultName=${resourceNames.keyVault};SecretName=${secretNames.mySqlConnectionString})'
      }
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

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

module webAppPrivateEndpoint 'modules/privateEndpoint.module.bicep' = if (usePrivateLinks) {
  name: 'webapp-privateEndpoint'
  params: {
    name: '${resourceNames.webApp}-pe'
    location: location
    tags: defaultTags
    privateDnsZoneId: privateDNSZone.id
    privateLinkServiceId: webApp.outputs.id
    subnetId: vnet.outputs.appSnetId
    subResource: 'sites'
  }
}

module funcPrivateEndpoint 'modules/privateEndpoint.module.bicep' = if (usePrivateLinks) {
  name: 'funcapp-privateEndpoint'
  params: {
    name: '${resourceNames.funcApp}-pe'
    location: location
    tags: defaultTags
    privateDnsZoneId: privateDNSZone.id
    privateLinkServiceId: funcApp.outputs.id
    subnetId: vnet.outputs.appSnetId
    subResource: 'sites'
  }
}

module mysql 'modules/mysql.module.bicep' = {
  name: 'mysql'
  params: {
    name: resourceNames.mysqlServer
    dbName: resourceNames.mysqlDatabase
    location: location
    tags: defaultTags
    adminLogin: 'dbuser'
    adminPassword: 'Qwertyuiop123!'
    skuName: 'GP_Gen5_2'
    skuTier: 'GeneralPurpose'
    mySQLVersion: '5.7'
  }
}

resource mySqlPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.mysql.database.azure.com'
  location: 'global'
}

module mySqlPrivateEndpoint 'modules/privateEndpoint.module.bicep' = if (usePrivateLinks) {
  name: 'mysql-privateEndpoint'
  params: {
    name: 'pe-${naming.mysqlServer.name}'
    location: location
    tags: defaultTags
    privateDnsZoneId: mySqlPrivateDNSZone.id
    privateLinkServiceId: mysql.outputs.mysqlServerId
    subnetId: vnet.outputs.appSnetId
    subResource: 'mysqlServer'
  }
}

module keyVault 'modules/keyvault.module.bicep' = {
  name: 'keyVault'
  params: {
    name: resourceNames.keyVault
    location: location
    skuName: keyVaultSku
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
      {
        tenantId: webApp.outputs.identity.tenantId
        objectId: webApp.outputs.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    secrets: [
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

module bastion 'modules/bastion.module.bicep' = if (includeBastion) {
  name: 'bastionDeployment'
  params: {
    name: resourceNames.bastion
    location: location    
    subnetId: vnet.outputs.bastionSnetId
  }
}

module jumpbox 'modules/vmjumpbox.module.bicep' = {
  name: 'jumpbox'
  params: {
    name: resourceNames.jumpboxVm
    subnetId: vnet.outputs.devOpsSnetId
    location: location
    dnsLabelPrefix: resourceNames.jumpboxVm
    adminPassword: jumpboxPassword
    includePublicIp: true
    includeVsCode: true
    tags: defaultTags
  }
}

output funcDeployment object = funcApp
output dataStorage object = dataStorage
output keyVault object = {
  id: keyVault.outputs.id
  name: keyVault.outputs.name
}
output bastion object = bastion
output vnet object = vnet
