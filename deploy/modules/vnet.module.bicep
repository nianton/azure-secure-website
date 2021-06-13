param name string
param location string = resourceGroup().location
param tags object = {}
param addressPrefix string
param includeBastion bool = true

param defaultSnet object
param appSnet object
param devOpsSnet object
param bastionSnet object
param integratedSnet object


var defaultSnetConfig = union({
  name: '${name}-default-snet'
}, defaultSnet)

var appSnetConfig = union({
  name: '${name}-app-snet'
}, appSnet)

var devOpsSnetConfig = union({
  name: '${name}-devops-snet'
}, devOpsSnet)

var bastionSnetConfig = union(bastionSnet, {
  name: 'AzureBastionSubnet'
})

var integratedSnetConfig = union({
  name: '${name}-integration-snet'
}, integratedSnet)

var subnetConfigs = includeBastion ? [
  defaultSnetConfig
  appSnetConfig
  devOpsSnetConfig
  integratedSnetConfig
  bastionSnetConfig
] : [
  defaultSnetConfig
  appSnetConfig
  devOpsSnetConfig
  integratedSnetConfig
]

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: subnetConfigs
  }
  tags: tags
}

output vnetId string = vnet.id
output defaultSnetId string = vnet.properties.subnets[0].id
output appSnetId string = vnet.properties.subnets[1].id
output devOpsSnetId string = vnet.properties.subnets[2].id
output integratedSnetId string = vnet.properties.subnets[3].id
output bastionSnetId string = includeBastion ? vnet.properties.subnets[4].id : json('null')
