param name string
param location string = resourceGroup().id
param tags object = {}

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

param queues array = [
  {
    name: 'messages'
    properties: {}
  }
]

// Currently tier value matches skuName value
var skuTier = skuName

var queueDefaultProperties = {
  enablePartitioning: false
  deadLetteringOnMessageExpiration: false
  defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
  duplicateDetectionHistoryTimeWindow: 'PT10M'
  lockDuration: 'PT5M'
  maxSizeInMegabytes: 1024
  requiresSession: false
  requiresDuplicateDetection: false
}

var defaultSASKeyName = 'RootManageSharedAccessKey'
var defaultAuthRuleResourceId = resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', name, defaultSASKeyName)

resource serviceBus 'Microsoft.ServiceBus/namespaces@2018-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
}

resource serviceBusQueues 'Microsoft.ServiceBus/namespaces/queues@2018-01-01-preview' = [for queue in queues: {
  name: '${serviceBus.name}/${queue.name}'
  properties: union(queueDefaultProperties, queue.properties)
}]

output id string = serviceBus.id
output queues array = [for (queue, i) in queues: {
  id: serviceBusQueues[i].id
  name: serviceBusQueues[i].name
}]
output authRuleResourceId string = defaultAuthRuleResourceId
output connectionString string = listkeys(defaultAuthRuleResourceId, '2017-04-01').primaryConnectionString
