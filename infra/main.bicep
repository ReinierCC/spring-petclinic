targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

// Optional parameters to override the default azd resource naming conventions
@description('Resource group name')
param resourceGroupName string = ''

@description('Container Apps environment name')
param containerAppsEnvironmentName string = ''

@description('Container registry name')
param containerRegistryName string = ''

@description('Application Insights name')
param applicationInsightsName string = ''

@description('Log Analytics workspace name')
param logAnalyticsName string = ''

@description('PostgreSQL server name')
param postgresServerName string = ''

@description('Key Vault name')
param keyVaultName string = ''

@description('User-assigned managed identity name')
param managedIdentityName string = ''

@description('PostgreSQL administrator login')
@secure()
param postgresAdminLogin string = 'petclinicadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('PostgreSQL database name')
param postgresDatabaseName string = 'petclinic'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User-assigned managed identity
module managedIdentity './core/identity/user-assigned-managed-identity.bicep' = {
  name: 'managed-identity'
  scope: rg
  params: {
    name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

// Container registry
module containerRegistry './core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container Apps environment
module containerAppsEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// PostgreSQL database
module postgresServer './core/database/postgresql/flexible-server.bicep' = {
  name: 'postgres-server'
  scope: rg
  params: {
    name: !empty(postgresServerName) ? postgresServerName : '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    location: location
    tags: tags
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    databaseName: postgresDatabaseName
    allowAzureIPsFirewall: true
  }
}

// Key Vault to store secrets
module keyVault './core/security/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Grant Key Vault access to managed identity
module keyVaultAccess './core/security/key-vault-access.bicep' = {
  name: 'key-vault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: managedIdentity.outputs.principalId
  }
}

// Store PostgreSQL connection string in Key Vault
module postgresConnectionStringSecret './core/security/key-vault-secret.bicep' = {
  name: 'postgres-connection-string-secret'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'POSTGRES-CONNECTION-STRING'
    secretValue: 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServer.outputs.POSTGRES_DOMAIN_NAME}:5432/${postgresDatabaseName}?sslmode=require'
  }
  dependsOn: [
    keyVaultAccess
  ]
}

// Container app for the web service
module web './core/host/container-app.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerRegistryName: containerRegistry.outputs.name
    containerCpuCoreCount: '1'
    containerMemory: '2Gi'
    containerName: 'web'
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' // Placeholder, will be replaced by azd
    targetPort: 8080
    env: [
      {
        name: 'SPRING_PROFILES_ACTIVE'
        value: 'postgres'
      }
      {
        name: 'SPRING_DATASOURCE_URL'
        value: 'jdbc:postgresql://${postgresServer.outputs.POSTGRES_DOMAIN_NAME}:5432/${postgresDatabaseName}?sslmode=require'
      }
      {
        name: 'SPRING_DATASOURCE_USERNAME'
        value: postgresAdminLogin
      }
      {
        name: 'SPRING_DATASOURCE_PASSWORD'
        secretRef: 'postgres-password'
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: monitoring.outputs.applicationInsightsConnectionString
      }
    ]
    secrets: [
      {
        name: 'postgres-password'
        value: postgresAdminPassword
      }
    ]
    identityType: 'UserAssigned'
    identityId: managedIdentity.outputs.id
  }
}

// Grant ACR pull permission to managed identity
module containerRegistryAccess './core/security/registry-access.bicep' = {
  name: 'container-registry-access'
  scope: rg
  params: {
    containerRegistryName: containerRegistry.outputs.name
    principalId: managedIdentity.outputs.principalId
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = managedIdentity.outputs.principalId
output SERVICE_WEB_NAME string = web.outputs.name
output SERVICE_WEB_URI string = web.outputs.uri
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output POSTGRES_DOMAIN_NAME string = postgresServer.outputs.POSTGRES_DOMAIN_NAME
