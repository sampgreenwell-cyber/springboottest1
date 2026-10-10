// Service infrastructure: one Container App, optionally published through APIM.
// Shared CLX platform resources (Container Apps environment, ACR, Key Vault, APIM,
// deploy identity) are referenced, never created. Environment values live in
// <env>.bicepparam. Deployed by the platform workflow per environment:
//   az deployment group create -g <RESOURCE_GROUP> -f infra/main.bicep -p infra/<env>.bicepparam
// with IMAGE_TAG set in the environment (read by the .bicepparam).
//
// infra/modules/ is copied from sampgreenwell-cyber/platform-bicep-modules (see its README);
// update it from there, not by hand.

@description('Service name (lowercase alnum or hyphen, max 15 chars)')
@maxLength(15)
param serviceName string

@description('Environment name, e.g. dev or qa')
param environmentName string

@description('Environment code used in resource names, e.g. d01 or q01')
param environmentCode string

@description('Azure region')
param location string = resourceGroup().location

@description('Existing Container Apps managed environment name')
param managedEnvironmentName string

@description('ACR login server the image is pulled from')
param acrLoginServer string

@description('Image repository path in ACR, e.g. lab/orders')
param imageRepository string

@description('Immutable image tag built by the pipeline, e.g. dev-20261009-142233-1a2b3c4')
@minLength(1)
param imageTag string

@description('Existing user-assigned identity with AcrPull on the registry and Key Vault Secrets User on the Key Vault')
param identityName string

@description('Existing Key Vault name in this resource group')
param keyVaultName string

@description('Key Vault secret names. Each becomes an env var: clx-subscription-key -> CLX_SUBSCRIPTION_KEY.')
param keyVaultSecretNames array

@description('Plain (non-secret) environment variables for the app container')
param appSettings array = []

@description('Publish through APIM (ingress locked to APIM IPs). false = internal to the Container Apps environment.')
param exposeViaApim bool = true

@description('Existing APIM service name in this resource group')
param apimName string

@description('Appended to the APIM API name, path and backend. Only for environments that share one APIM (e.g. a lab), so qa does not overwrite dev\'s API.')
param apimApiSuffix string = ''

@description('APIM only lets through callers with an Entra ID token for jwtAudience issued to allowedCallerClientId: 401 without a valid token, 403 for any other app. Same as applyCoreAuthorization on the CLX core-api.')
param requireCallerToken bool = false

@description('Token audience when requireCallerToken=true: this service\'s app registration (application ID URI or client ID)')
param jwtAudience string = ''

@description('Client ID of the one app allowed to call (appid/azp claim), e.g. the BFF, when requireCallerToken=true')
param allowedCallerClientId string = ''

@description('Application port (keep in sync with server.port in application.yml)')
param targetPort int = 8080

@description('Minimum replicas')
param minReplicas int = 1

@description('Maximum replicas')
param maxReplicas int = 3

@description('Datadog environment tag, e.g. lab-dev')
param ddEnv string

@description('Datadog tags, e.g. team:commerce,component:api')
param ddTags string

@description('Run the Datadog Agent sidecar for APM. Off on non-prod (Datadog cost cutback).')
param enableDatadogSidecar bool = false

@description('Tags for resources')
param tags object

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: managedEnvironmentName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = if (exposeViaApim) {
  name: apimName
}

var appName = 'ca-lab-${serviceName}-${environmentCode}'

// Lock ingress to APIM's outbound IPs, read at deploy time (Basic tier has no VNet integration).
var apimIngressCidrs = exposeViaApim
  ? map(apim!.properties.outboundPublicIPAddresses ?? apim!.properties.publicIPAddresses, ip => '${ip}/32')
  : []

var secretEnv = map(keyVaultSecretNames, secretName => {
  name: toUpper(replace(secretName, '-', '_'))
  secretRef: secretName
})

var platformEnv = [
  {
    name: 'SPRING_PROFILES_ACTIVE'
    value: environmentName
  }
  {
    name: 'DD_SERVICE'
    value: serviceName
  }
  {
    name: 'DD_ENV'
    value: ddEnv
  }
  {
    name: 'DD_VERSION'
    value: imageTag
  }
  {
    name: 'DD_TAGS'
    value: ddTags
  }
  {
    // The tracer has nowhere to send traces without the sidecar; turn it off rather than log connection errors.
    name: 'DD_TRACE_ENABLED'
    value: enableDatadogSidecar ? 'true' : 'false'
  }
]

module app 'modules/container-app-service.bicep' = {
  name: '${serviceName}-app'
  params: {
    name: appName
    location: location
    managedEnvironmentId: managedEnvironment.id
    image: '${acrLoginServer}/${imageRepository}:${imageTag}'
    registryServer: acrLoginServer
    userAssignedIdentityResourceId: identity.id
    targetPort: targetPort
    healthPath: '/health'
    externalIngress: exposeViaApim
    ingressAllowCidrs: apimIngressCidrs
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    env: concat(platformEnv, appSettings, secretEnv)
    keyVaultName: keyVaultName
    keyVaultSecretNames: keyVaultSecretNames
    enableDatadogSidecar: enableDatadogSidecar
    ddEnv: ddEnv
    tags: tags
  }
}

module api 'modules/apim-api.bicep' = if (exposeViaApim) {
  name: '${serviceName}-apim'
  params: {
    apimName: apimName
    name: '${serviceName}${apimApiSuffix}'
    backendUrl: 'https://${app.outputs.fqdn}'
    enableJwtValidation: requireCallerToken
    tenantId: tenant().tenantId
    jwtAudience: jwtAudience
    allowedCallerClientId: allowedCallerClientId
  }
}

output containerAppName string = app.outputs.containerAppName
output containerAppFqdn string = app.outputs.fqdn
output publicBaseUrl string = exposeViaApim ? '${apim!.properties.gatewayUrl}/${serviceName}${apimApiSuffix}' : ''
