# Azure Deployment Quick Reference

## Prerequisites Installation

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure Developer CLI (azd)
curl -fsSL https://aka.ms/install-azd.sh | bash

# Verify installations
az --version
azd version
```

## First-Time Setup

```bash
# 1. Login to Azure
az login
azd auth login

# 2. Create environment
azd env new petclinic-prod

# 3. Set subscription (get from: az account list)
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>

# 4. Set region (optional, defaults to eastus)
azd env set AZURE_LOCATION eastus

# 5. Set PostgreSQL password
azd env set POSTGRES_ADMIN_PASSWORD <secure-password>

# 6. Deploy everything
azd up
```

## Common Commands

### Deployment
```bash
# Deploy infrastructure and application
azd up

# Deploy only infrastructure
azd provision

# Deploy only application code
azd deploy

# Preview what will be deployed
azd provision --preview
```

### Environment Management
```bash
# List all environments
azd env list

# Select an environment
azd env select <environment-name>

# Show current environment
azd env get-values

# Set environment variable
azd env set KEY value

# Delete environment
azd env delete <environment-name>
```

### Monitoring
```bash
# View application logs
azd monitor --logs

# View overview
azd show

# Open Azure Portal
azd show --portal
```

### Resource Management
```bash
# List all resources in environment
az resource list --resource-group <rg-name> -o table

# Delete all resources
azd down

# Force delete without confirmation
azd down --force --purge
```

## Docker Commands

### Local Build and Test
```bash
# Build Docker image
docker build -t spring-petclinic .

# Run container locally
docker run -p 8080:8080 spring-petclinic

# Run with PostgreSQL
docker compose up postgres
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=postgres \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/petclinic \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  spring-petclinic
```

## Azure CLI Commands

### Container Apps
```bash
# List container apps
az containerapp list -g <resource-group> -o table

# Show container app details
az containerapp show -n <app-name> -g <resource-group>

# View logs
az containerapp logs show -n <app-name> -g <resource-group> --follow

# Update container app
az containerapp update -n <app-name> -g <resource-group> --image <new-image>
```

### PostgreSQL
```bash
# List databases
az postgres flexible-server db list -g <resource-group> -s <server-name> -o table

# Connect to database
az postgres flexible-server connect -n <server-name> -u <username> -d petclinic

# Show connection string
az postgres flexible-server show-connection-string -s <server-name>
```

### Container Registry
```bash
# Login to ACR
az acr login --name <registry-name>

# List images
az acr repository list --name <registry-name> -o table

# Show image tags
az acr repository show-tags --name <registry-name> --repository <repo-name>
```

## GitHub Actions

### Setup Secrets
```bash
# Create service principal
az ad sp create-for-rbac --name "github-petclinic" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth

# Add to GitHub Secrets:
# - AZURE_CREDENTIALS (output from above)
# - POSTGRES_ADMIN_PASSWORD
```

### Workflow
```bash
# Push to main branch triggers deployment
git push origin main

# View workflow runs
gh run list

# View workflow logs
gh run view <run-id> --log
```

## Troubleshooting

### Check Application Health
```bash
# Get app URL
azd show

# Test health endpoint
curl https://<app-url>/actuator/health
```

### View Application Insights
```bash
# Get Application Insights resource
az monitor app-insights component show \
  -g <resource-group> --app <app-name>

# Query logs (last hour)
az monitor app-insights query \
  --app <app-id> \
  --analytics-query "requests | where timestamp > ago(1h)"
```

### Reset Environment
```bash
# Delete and recreate
azd down --force --purge
azd env new <environment-name>
azd up
```

## Cost Management

```bash
# Show current costs
az consumption usage list --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>

# Set budget alerts (via Azure Portal)
# Portal -> Cost Management + Billing -> Budgets
```

## Security Best Practices

```bash
# Rotate PostgreSQL password
az postgres flexible-server update \
  -g <resource-group> -n <server-name> \
  --admin-password <new-password>

# Update container app secret
azd env set POSTGRES_ADMIN_PASSWORD <new-password>
azd provision

# Review access with Managed Identity
az role assignment list --assignee <managed-identity-id>
```

## Useful Environment Variables

```bash
# Required
AZURE_ENV_NAME=<your-environment-name>
AZURE_SUBSCRIPTION_ID=<subscription-id>
POSTGRES_ADMIN_PASSWORD=<secure-password>

# Optional
AZURE_LOCATION=eastus
AZURE_RESOURCE_GROUP=<custom-rg-name>
CONTAINER_REGISTRY_NAME=<custom-registry-name>
```

## Getting Help

```bash
# Azure CLI help
az --help
az containerapp --help

# Azure Developer CLI help
azd --help
azd up --help

# View deployment errors
azd monitor --logs
az monitor activity-log list -g <resource-group>
```

## Quick Links

- [Azure Portal](https://portal.azure.com)
- [Azure Status](https://status.azure.com)
- [Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Documentation](https://learn.microsoft.com/azure)
