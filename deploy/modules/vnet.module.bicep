param name string
param location string = resourceGroup().location
param tags object = {}
param addressPrefix string = ''
param includeBastion bool = true

param appSnet object
param devOpsSnet object
param bastionSnet object
param integratedSnet object

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
  name: '${name}-intgtr-snet'
}, integratedSnet)

var subnetConfigs = includeBastion ? [
  appSnetConfig
  devOpsSnetConfig
  integratedSnet
  bastionSnetConfig
] : [
  appSnetConfig
  devOpsSnetConfig
  integratedSnet
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
output appSnetId string = vnet.properties.subnets[0].id
output devOpsSnetId string = vnet.properties.subnets[1].id
output integratedSnetId string = vnet.properties.subnets[2].id
output bastionSnetId string = includeBastion ? vnet.properties.subnets[3].id : json('null')
