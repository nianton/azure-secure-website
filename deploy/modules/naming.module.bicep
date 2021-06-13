param prefix string = ''
param suffix string = ''
param useDash bool = true
param locationSlug string = ''

var resourceTypeSlug = {
  vnet: 'vnet'
  snet: 'snet-01'
  funcApp: 'func'
  webApp: 'web'
  keyVault: 'kv'
  serviceBusNamespace: 'sbns'
  virtualMachine: 'vm'
  bastion: 'bastion'
  storage: 'st'
}

var separator = useDash ? '-' : ''
var preSlug = empty(prefix) ? '' : (empty(locationSlug) ? '${prefix}${separator}' : '${prefix}${separator}${locationSlug}${separator}')
var sufSlug = empty(suffix) ? '' : (empty(locationSlug) ? '${separator}${suffix}' : '${separator}${locationSlug}${separator}${suffix}')

var resourceNames = {
  vnet: '${preSlug}${resourceTypeSlug.vnet}${sufSlug}'
  snet: '${preSlug}${resourceTypeSlug.snet}${sufSlug}'
  virtualMachine: '${preSlug}${resourceTypeSlug.snet}${sufSlug}'
  funcApp: '${preSlug}${resourceTypeSlug.funcApp}${sufSlug}'
  webApp: '${preSlug}${resourceTypeSlug.webApp}${sufSlug}'
  keyVault: '${preSlug}${resourceTypeSlug.keyVault}${sufSlug}'
  serviceBusNamespace: '${preSlug}${resourceTypeSlug.serviceBusNamespace}${sufSlug}'
  bastion: '${preSlug}${resourceTypeSlug.bastion}${sufSlug}'
  storage: '${preSlug}${resourceTypeSlug.storage}${sufSlug}'
}

output vnet string = resourceNames.vnet
output snet string = resourceNames.snet
output funcApp string = resourceNames.funcApp
output webApp string = resourceNames.webApp
output keyVault string = resourceNames.keyVault
output bastion string = resourceNames.bastion
output virtualMachine string = resourceNames.virtualMachine
