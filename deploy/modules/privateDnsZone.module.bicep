param name string
param tags object = {}
param registrationEnabled bool = false
param vnetIds array

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'Global'
  tags: tags  
}

module privateDnsZoneLinks 'privateDnsZoneLink.module.bicep' = if (!empty(vnetIds)) {
  name: 'PrivateDnsZoneLinks-Deployment'
  params: {
    privateDnsZoneName: privateDnsZone.name
    vnetIds: vnetIds
    registrationEnabled: registrationEnabled
    tags: tags
  }
}

output id string = privateDnsZone.id
output linkIds array = privateDnsZoneLinks.outputs.ids
