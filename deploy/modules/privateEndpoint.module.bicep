param name string
param location string
param tags object = {}
param subnetId string
param privateLinkServiceId string
param privateDnsZoneId string

@allowed([
  'sites'
  'sqlServer'
  'mysqlServer'
  'blob'
  'file'
  'queue'
  'redisCache'
  'namespace'
])
param subResource string

var privateLinkConnectionName = 'prvlnk-${name}'

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateLinkConnectionName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            subResource
          ]
        }
      }
    ]
  }
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpoint.name}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}
