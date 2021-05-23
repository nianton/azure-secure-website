param namePrefix string
param location string = resourceGroup().location
param adminLogin string
param tags object = {}

@secure()
@minLength(8)
@maxLength(128)
param adminPassword string

@allowed([
  2
  4
  8
  16
  32
])
param skuCapacity int = 2

@allowed([
  'GP_Gen5_2'
  'GP_Gen5_4'
  'GP_Gen5_8'
  'GP_Gen5_16'
  'GP_Gen5_32'
  'MO_Gen5_2'
  'MO_Gen5_4'
  'MO_Gen5_8'
  'MO_Gen5_16'
  'MO_Gen5_32'
])
param skuName string = 'GP_Gen5_2'

@allowed([
  51200
  102400
])
param skuSizeInMB int = 51200

@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'GeneralPurpose'

param skuFamily string = 'Gen5'

@allowed([
  '5.6'
  '5.7'
])
param mySQLVersion string

var resourceNames = {
  server: '${namePrefix}-dbsrv'
  database: '${namePrefix}-db'
}

resource dbServer 'Microsoft.DBForMySQL/servers@2017-12-01-preview' = {
  name: resourceNames.server
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
    size: string(skuSizeInMB)
    family: skuFamily
  }
  properties: {
    createMode: 'Default'
    version: mySQLVersion
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    storageProfile: {
      storageMB: skuSizeInMB
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    sslEnforcement: 'Disabled'
  }
}

resource firewallRules 'Microsoft.DBForMySQL/servers/firewallRules@2017-12-01-preview' = {
  name: '${dbServer.name}/allowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.DBForMySQL/servers/databases@2017-12-01-preview' = {
  name: '${dbServer.name}/${resourceNames.database}'  
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

output connectionString string = 'Database=${database.name}};Data Source=${dbServer.properties.fullyQualifiedDomainName};User Id=${adminLogin}@${dbServer.name};Password=${adminPassword}'
