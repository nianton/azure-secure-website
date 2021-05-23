param name string
param location string = resourceGroup().location
param tags object = {}
param appSettings array = []
param managedIdentity bool = false

@allowed([
  'P1v3'
  'P2v3'
  'P3v3'
])
param skuName string = 'P1v3'

param appDeployRepoUrl string = ''
param appDeployBranch string = ''
param subnetIdForIntegration string = ''

var skuTier =  substring(skuName, 0, 1) == 'S' ? 'Standard' : 'PremiumV3'
var webAppServicePlanName = '${name}-asp'
var webAppInsName = '${name}-appins'
var createSourceControl = !empty(appDeployRepoUrl)
var createNetworkConfig = !empty(subnetIdForIntegration)

module webAppIns './appInsights.module.bicep' = {
  name: webAppInsName
  params: {
    name: webAppInsName
    location: location
    tags: tags
    project: name
  }
}

resource webAppServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: webAppServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: name
  location: location  
  identity: {
    type: managedIdentity ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: webAppServicePlan.id
    siteConfig: {
      appSettings: concat([
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '10.14.1'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: webAppIns.outputs.instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${webAppIns.outputs.instrumentationKey}'
        }
      ], appSettings)
    }
    httpsOnly: true
  }
  tags: tags
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = if (createNetworkConfig) {
  name: '${webApp.name}/VirtualNetwork'
  properties: {
    subnetResourceId: subnetIdForIntegration
  }
}

resource appSourceControl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = if (createSourceControl) {
  name: '${webApp.name}/web'
  properties: {
    branch: appDeployBranch
    repoUrl: appDeployRepoUrl
    isManualIntegration: true
  }
}

output id string = webApp.id
output name string = webApp.name
output appServicePlanId string = webAppServicePlan.id
output identity object = {
  tenantId: webApp.identity.tenantId
  principalId: webApp.identity.principalId
  type: webApp.identity.type
}
output applicationInsights object = webAppIns
