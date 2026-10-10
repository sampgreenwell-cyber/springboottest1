using './main.bicep'

// qa: the dev image, promoted after approval by the owning team.
param serviceName = 'springboot1'
param environmentName = 'qa'
param environmentCode = 'q01'
param location = 'East US'
param managedEnvironmentName = 'cae-platform-shared'
param acrLoginServer = 'samgplabacr.azurecr.io'
param imageRepository = 'lab/springboot1'
// Set by the pipeline. Locally: $env:IMAGE_TAG = '<tag>' before az deployment group what-if.
param imageTag = readEnvironmentVariable('IMAGE_TAG', '')
// Lab identity (from the lab setup). It has AcrPull on
// samgplabacr and Key Vault Secrets User on kv-samgp-lab.
param identityName = 'id-lab-apps-qa'
param keyVaultName = 'kv-samgp-lab'
param keyVaultSecretNames = [
  'dd-api-key'
]
param appSettings = []
param exposeViaApim = true
// Lab: dev and qa share one APIM, so qa publishes as <name>-qa-api on /<name>-qa.
param apimApiSuffix = '-qa'
param apimName = 'apim-samgp-lab'
// Caller check at APIM (off until the app registrations exist): when true, only an Entra ID token
// for jwtAudience issued to allowedCallerClientId (e.g. the BFF) gets through; 401/403 otherwise.
param requireCallerToken = false
param jwtAudience = ''
param allowedCallerClientId = ''
param minReplicas = 1
param maxReplicas = 3
param ddEnv = 'lab-qa'
param ddTags = 'owner:guests,component:api,service:springboot1'
param enableDatadogSidecar = false
param tags = {
  ApplicationCode: 'LAB'
  ApplicationName: 'LAB'
  Environment: 'QA'
  ManagedBy: 'backstage'
  SourceRepository: 'sampgreenwell-cyber/springboottest1'
}
