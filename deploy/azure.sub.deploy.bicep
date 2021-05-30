targetScope = 'subscription'

@description('Name of the resource group to create the resources in. Leave empty to use naming convention {project}-{environment}-rg.')
param resourceGroupName string = ''
param location string = 'westeurope'
param project string = 'secweb2'
param environment string = 'dev'

@secure()
@description('Jumpbox VM password')
param jumpboxPassword string = 'Qwertyuiop[]|'

var rgName = empty(resourceGroupName) ? '${project}-${environment}-rg' : resourceGroupName

resource group 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgName
  location: location
}

module appDeployment './azure.deploy.bicep' = {
  name: 'appDeployment'
  scope: resourceGroup(group.name)
  params: {
    location: group.location
    environment: environment
    project: project
    jumpboxPassword: jumpboxPassword
  }
}
