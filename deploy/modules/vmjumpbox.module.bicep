@minLength(3)
@maxLength(15)
param name string
param location string = resourceGroup().location
param adminUserName string = 'vmadmin'

@secure()
param adminPassword string
param subnetId string
param tags object = {}
param dnsLabelPrefix string
param includePublicIp bool = true
param includeVsCode bool = true

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2016-Nano-Server'
  '2016-Datacenter-with-Containers'
  '2016-Datacenter'
  '2019-Datacenter'
])
@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2019-Datacenter'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_D2_v3'

var resourceNames = {
  storageAccount: 'st${name}'
  nic: 'nic-${name}'
  publicIP: 'pip-${name}'
  networkSecurityGroup: 'default-nsg'
}

module stg 'storage.module.bicep' = {
  name: 'storageAccount-${resourceNames.storageAccount}'
  params: {
    name: resourceNames.storageAccount
    location: location
    tags: tags
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: resourceNames.networkSecurityGroup
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (includePublicIp) {
  name: resourceNames.publicIP
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

var nicIpConfigurationDefaults = {
  privateIPAllocationMethod: 'Dynamic'
  subnet: {
    id: subnetId
  }
}

var nicIpConfigurationWithPip = {
  publicIPAddress: {
    id: pip.id
  }
}

var nicIpConfigurationProperties = includePublicIp ? nicIpConfigurationDefaults : union(nicIpConfigurationDefaults, nicIpConfigurationWithPip)

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: resourceNames.nic
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: nicIpConfigurationProperties
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: name
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stg.outputs.primaryEndpoints.blob
      }
    }
  }
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (includeVsCode) {
  name: '${vm.name}/config-app'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./Install-VSCode.ps1 -EnableContextMenus'
      fileUris: [
        'https://raw.githubusercontent.com/PowerShell/vscode-powershell/master/scripts/Install-VSCode.ps1'
      ]
    }
    protectedSettings: {}
  }
}

output hostname string = includePublicIp ? pip.properties.dnsSettings.fqdn : ''
