# Azure Deployment Guide for Spring PetClinic

This guide explains how to deploy the Spring PetClinic application to Azure using Azure Developer CLI (azd).

## Architecture Overview

The application is deployed to Azure using the following services:

- **Azure Container Apps**: Hosts the Spring Boot application in a container
- **Azure Database for PostgreSQL**: Managed PostgreSQL database for persistent data storage
- **Azure Container Registry**: Stores Docker images
- **Application Insights**: Application performance monitoring and logging
- **Log Analytics Workspace**: Centralized logging
- **Azure Key Vault**: Securely stores database credentials and connection strings
- **User-Assigned Managed Identity**: Provides secure access to Azure resources without storing credentials

## Prerequisites

Before deploying to Azure, ensure you have:

1. **Azure Subscription**: An active Azure subscription
2. **Azure CLI**: Install from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **Azure Developer CLI (azd)**: Install from [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
4. **Docker**: Install from [here](https://docs.docker.com/get-docker/) (for local testing)
5. **Java 17 or later**: Required for building the application

## Quick Start - Deploy to Azure

### 1. Login to Azure

```bash
az login
azd auth login
```

### 2. Initialize the Environment

Create a new environment (this is a one-time setup):

```bash
azd env new <your-environment-name>
```

For example:
```bash
azd env new petclinic-prod
```

### 3. Set Required Environment Variables

```bash
# Set your Azure subscription ID
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>

# Set the Azure region (optional, defaults to eastus)
azd env set AZURE_LOCATION eastus

# Set PostgreSQL admin password (required)
azd env set POSTGRES_ADMIN_PASSWORD <your-secure-password>
```

To get your subscription ID:
```bash
az account show --query id -o tsv
```

### 4. Deploy Everything

Deploy the infrastructure and application with a single command:

```bash
azd up
```

This command will:
- Provision all Azure resources defined in `infra/main.bicep`
- Build the Docker container
- Push the container to Azure Container Registry
- Deploy the application to Azure Container Apps

The deployment typically takes 10-15 minutes. Once complete, azd will display the URL where your application is running.

## Manual Deployment Steps

If you prefer to deploy in separate steps:

### 1. Provision Infrastructure Only

```bash
azd provision
```

### 2. Deploy Application Only

```bash
azd deploy
```

## Local Development and Testing

### Build and Run Locally

```bash
./mvnw spring-boot:run
```

Access at: http://localhost:8080

### Build Docker Image Locally

```bash
docker build -t spring-petclinic .
docker run -p 8080:8080 spring-petclinic
```

### Run with PostgreSQL Locally

Using Docker Compose:

```bash
docker compose up postgres
SPRING_PROFILES_ACTIVE=postgres ./mvnw spring-boot:run
```

## Configuration

### Environment Variables

The application uses the following environment variables when deployed to Azure:

- `SPRING_PROFILES_ACTIVE`: Set to `postgres` to use PostgreSQL
- `SPRING_DATASOURCE_URL`: JDBC URL for PostgreSQL connection
- `SPRING_DATASOURCE_USERNAME`: Database username
- `SPRING_DATASOURCE_PASSWORD`: Database password (stored in Key Vault)
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: Application Insights connection string

### Azure Resources Configuration

You can customize the deployment by modifying `infra/main.parameters.json` or setting environment variables:

```bash
# Custom resource names
azd env set CONTAINER_APPS_ENVIRONMENT_NAME my-custom-env
azd env set CONTAINER_REGISTRY_NAME mycustomregistry
azd env set POSTGRES_SERVER_NAME my-postgres-server
```

## Monitoring and Logs

### View Application Logs

```bash
# View logs using Azure CLI
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group-name> \
  --follow

# Or using azd
azd monitor --logs
```

### Application Insights

Access Application Insights in the Azure Portal to view:
- Request metrics
- Performance data
- Error tracking
- Dependency tracking
- Live metrics

## CI/CD with GitHub Actions

A GitHub Actions workflow is provided at `.github/workflows/azure-deployment.yml`.

### Setup GitHub Actions

1. **Configure Azure Credentials**:

   Create a service principal:
   ```bash
   az ad sp create-for-rbac --name "github-actions-petclinic" \
     --role contributor \
     --scopes /subscriptions/<subscription-id> \
     --sdk-auth
   ```

2. **Add GitHub Secrets**:

   In your GitHub repository settings, add these secrets:
   - `AZURE_CLIENT_ID`: From service principal output
   - `AZURE_TENANT_ID`: From service principal output
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
   - `POSTGRES_ADMIN_PASSWORD`: Your PostgreSQL admin password

3. **Add GitHub Variables**:
   - `AZURE_ENV_NAME`: Your environment name
   - `AZURE_LOCATION`: Azure region (e.g., eastus)

4. **Push to GitHub**:

   The workflow will automatically deploy on push to the main branch.

## Updating the Application

To deploy updates:

```bash
# Make your code changes, then:
azd deploy
```

Or push to GitHub and let the CI/CD pipeline handle it.

## Cleanup

To delete all Azure resources:

```bash
azd down
```

This will remove all resources created by azd, including:
- Container Apps
- PostgreSQL database
- Container Registry
- Application Insights
- Key Vault
- Log Analytics Workspace
- Managed Identity
- Resource Group

## Cost Estimation

The deployed resources use the following pricing tiers by default:

- **Container Apps**: Consumption-based
- **PostgreSQL**: Burstable tier (B1ms)
- **Container Registry**: Basic tier
- **Application Insights**: Pay-as-you-go
- **Log Analytics**: Pay-as-you-go

Estimated monthly cost: ~$20-50 USD (varies by usage and region)

For production workloads, consider upgrading to:
- PostgreSQL: General Purpose tier for better performance
- Container Registry: Standard or Premium for geo-replication
- Container Apps: Dedicated tier for guaranteed resources

## Troubleshooting

### Common Issues

1. **Deployment fails with "name already exists"**:
   - Resource names must be globally unique
   - Set custom names using environment variables

2. **PostgreSQL connection fails**:
   - Verify firewall rules allow Azure services
   - Check connection string in Application Insights logs

3. **Container fails to start**:
   - Check logs: `azd monitor --logs`
   - Verify environment variables are set correctly

4. **Build fails**:
   - Ensure Java 17 is installed
   - Clear Maven cache: `./mvnw clean`

### Get Help

- View azd logs: `azd monitor --logs`
- Check Azure Portal for detailed resource status
- Review Application Insights for application errors

## Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Azure Database for PostgreSQL Documentation](https://learn.microsoft.com/en-us/azure/postgresql/)
- [Spring Boot on Azure](https://learn.microsoft.com/en-us/azure/developer/java/spring/)

## License

Same as Spring PetClinic - Apache License 2.0
