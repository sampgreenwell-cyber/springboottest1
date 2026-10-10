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
// Lab: dev and qa share one APIM, so qa stays internal (their <name>-api would collide).
param exposeViaApim = false
param apimName = 'apim-samgp-lab'
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
