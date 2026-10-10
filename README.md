# springboot1

A Spring Boot service on CLX Container Apps

Spring Boot 4 (Java 21, WebFlux) service on the lab Azure Container Apps environment. Created from the `spring-container-app` Backstage template; owned by `group:default/guests`.

| | dev | qa |
|---|---|---|
| Container App | `ca-lab-springboot1-d01` | `ca-lab-springboot1-q01` |
| Resource group | `rg-platform-services` | `rg-platform-services` |
| Public URL (APIM) | `https://apim-samgp-lab.azure-api.net/springboot1` | internal only (lab shares one APIM with dev) |
| Datadog | `service:springboot1 env:lab-dev` | `service:springboot1 env:lab-qa` |

## Run locally
```bash
./mvnw spring-boot:run
curl http://localhost:8080/health
```

## How it ships
`.github/workflows/ci-cd.yaml` calls the shared platform pipeline (`sampgreenwell-cyber/platform-workflows`, `bicep-container-app.yaml@v1`):

1. **Pull request:** build and test (`./mvnw verify`), Snyk code and dependency scans, Docker build check. Nothing is deployed.
2. **Merge to master:** builds one image, `lab/springboot1:dev-<timestamp>-<sha>`, pushes it to `samgplabacr`, then deploys `infra/` to dev.
3. **Promotion:** the same image is deployed to qa once a member of `group:default/guests` approves the waiting `qa` deployment in the Actions run.

Deployment is `az deployment group create` with `infra/main.bicep` and `infra/<env>.bicepparam`. The pipeline sets `IMAGE_TAG`, which the parameter files read. Azure sign-in uses OIDC; the settings are variables on the repository's `dev` and `qa` GitHub environments.

## Common changes
- **Add a setting:** add `{ name: 'MY_SETTING', value: '...' }` to `appSettings` in each `infra/<env>.bicepparam`.
- **Add a secret:** create it in each environment's Key Vault (`kv-samgp-lab`, `kv-samgp-lab`), then add its name to `keyVaultSecretNames`. It becomes an environment variable automatically: `my-api-key` becomes `MY_API_KEY`.
- **Scale:** `minReplicas` / `maxReplicas` in the parameter files.
- **APM traces:** set `enableDatadogSidecar = true` (adds a Datadog Agent sidecar; non-prod is off for cost).

Preview an infrastructure change locally (needs Reader on the resource group):
```powershell
$env:IMAGE_TAG = '<a tag that exists in ACR>'
az deployment group what-if -g rg-platform-services -f infra/main.bicep -p infra/dev.bicepparam
```

## Platform contract
The shared pipeline relies on these; keep them in place:
- `Dockerfile` at the repo root, listening on port 8080, with `GET /health` returning 200.
- Maven wrapper (`mvnw`) and `pom.xml` at the root.
- `infra/main.bicep` plus `infra/dev.bicepparam` and `infra/qa.bicepparam`, reading `IMAGE_TAG`.
- `infra/modules/` is copied from `sampgreenwell-cyber/platform-bicep-modules`; update it from there.
