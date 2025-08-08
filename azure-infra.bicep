param rgName string = 'rg-on-24-09-christoph'
@secure()
param postgresAdminPassword string
@secure()
param appServiceSecret string

// Azure Storage Account mit Blob-Service
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'mystartupst${uniqueString(rgName)}'
  location: 'westeurope'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
  }
}

// Blob Container für Uploads
resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/uploads'
  properties: {
    publicAccess: 'None'
  }
}

// Blob Container für Assets
resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/assets'
  properties: {
    publicAccess: 'None'
  }
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'myacr${uniqueString(rgName)}'
  location: 'westeurope'
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// VNet mit zwei Subnetzen
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'myStartupVNet'
  location: 'westeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'dbSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'postgresDelegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'webappSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'webappDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// NSG für dbSubnet
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'dbSubnet-nsg'
  location: 'westeurope'
  properties: {
    securityRules: [
      {
        name: 'Allow-Postgres-From-WebSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationPortRanges: ['5432']
          destinationAddressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// Private DNS Zone für PostgreSQL
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'mystartup-postgres.private.postgres.database.azure.com'
  location: 'global'
}

// PostgreSQL Flexible Server
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: 'mypgserver${uniqueString(rgName)}'
  location: 'westeurope'
  properties: {
    administratorLogin: 'pgadmin'
    administratorLoginPassword: postgresAdminPassword
    version: '17'
    storage: {
      storageSizeGB: 32
    }
    network: {
      delegatedSubnetResourceId: vnet.properties.subnets[0].id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
  }
  sku: {
    name: 'Standard_D2ds_v5'
    tier: 'GeneralPurpose'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'myStartupAppServicePlan'
  location: 'westeurope'
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
  }
}

// App Service mit VNet-Integration (webappSubnet) und AppSettings (z.B. für Secrets)
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: 'myStartupAppService${uniqueString(rgName)}'
  location: 'westeurope'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      vnetRouteAllEnabled: true
      vnetName: vnet.name
      appSettings: [
        {
          name: 'MY_APP_SECRET'
          value: appServiceSecret
        }
      ]
    }
    virtualNetworkSubnetId: vnet.properties.subnets[1].id
  }
}

// Azure Front Door mit WAF
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'myFrontDoorProfile'
  location: 'Global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}