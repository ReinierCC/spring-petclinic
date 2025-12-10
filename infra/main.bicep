// Main Bicep template for deploying Spring PetClinic to AKS

@description('The name of the environment (e.g., dev, prod)')
param environmentName string = 'dev'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the AKS cluster')
param aksClusterName string = 'aks-petclinic-${environmentName}'

@description('The name of the container registry')
param acrName string = 'acrpetclinic${uniqueString(resourceGroup().id)}'

@description('The name of the PostgreSQL server')
param postgresServerName string = 'psql-petclinic-${uniqueString(resourceGroup().id)}'

@description('PostgreSQL administrator username')
@secure()
param postgresAdminUsername string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('The name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string = 'law-petclinic-${environmentName}'

@description('The name of the Application Insights instance')
param appInsightsName string = 'appi-petclinic-${environmentName}'

@description('The name of the Key Vault')
param keyVaultName string = 'kv-petclinic-${take(uniqueString(resourceGroup().id), 6)}'

@description('The name of the managed identity')
param managedIdentityName string = 'id-petclinic-${environmentName}'

@description('AKS node count')
param aksNodeCount int = 2

@description('AKS node VM size')
param aksNodeVmSize string = 'Standard_D2s_v3'

// Create Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Create User-Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// Create Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Assign AcrPull role to managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalType: 'ServicePrincipal'
  }
}

// Create Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    enableRbacAuthorization: false
  }
}

// Create PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    version: '16'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// Create PostgreSQL database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgresServer
  name: 'petclinic'
}

// Configure PostgreSQL firewall rule to allow Azure services
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Store PostgreSQL connection string in Key Vault
resource postgresConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'postgres-connection-string'
  properties: {
    value: 'jdbc:postgresql://${postgresServer.properties.fullyQualifiedDomainName}:5432/petclinic?sslmode=require'
  }
}

resource postgresUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'postgres-username'
  properties: {
    value: postgresAdminUsername
  }
}

resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'postgres-password'
  properties: {
    value: postgresAdminPassword
  }
}

// Create AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: aksClusterName
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: aksNodeCount
        vmSize: aksNodeVmSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// Outputs
output aksClusterName string = aksCluster.name
output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output keyVaultName string = keyVault.name
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
