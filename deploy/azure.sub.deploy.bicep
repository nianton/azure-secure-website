targetScope = 'subscription'

@description('Name of the resource group to create the resources in. Leave empty to use naming convention {project}-{environment}-rg.')
param resourceGroupName string = ''
param location string = 'westeurope'
param project string = 'secweb6'
param environment string = 'dev'

@secure()
@description('Jumpbox VM password')
param jumpboxPassword string

var tags = {
  environment: environment
  project: project
  criticality: 'medium'
}

var rgName = empty(resourceGroupName) ? 'rg-${project}-${environment}' : resourceGroupName

resource group 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgName
  location: location
  tags: tags
}

module naming 'modules/naming.module.bicep' = {
  scope: resourceGroup(group.name)
  name: 'NamingDeployment'
  params: {
    suffix: [
      project
      environment
    ]
  }
}

module appDeployment './azure.deploy.bicep' = {
  name: 'appDeployment'
  scope: resourceGroup(group.name)
  params: {
    location: group.location
    environment: environment
    project: project
    jumpboxPassword: jumpboxPassword
    naming: naming.outputs.names
    tags: tags
  }
}
