param name string
param location string
param tags object = {}
param containerAppsEnvironmentId string
param containerRegistryName string
param containerCpuCoreCount string = '0.5'
param containerMemory string = '1Gi'
param containerName string
param containerImage string
param targetPort int = 80
param env array = []
param secrets array = []
param identityType string = 'None'
param identityId string = ''

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: identityType == 'UserAssigned' ? {
    type: identityType
    userAssignedIdentities: {
      '${identityId}': {}
    }
  } : {
    type: identityType
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: identityType == 'UserAssigned' ? identityId : ''
        }
      ]
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
          env: env
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

output id string = containerApp.id
output name string = containerApp.name
output uri string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
