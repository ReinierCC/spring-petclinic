# Azure Deployment Guide for Spring PetClinic

This guide provides step-by-step instructions to deploy the Spring PetClinic application to Azure using Azure Developer CLI (azd).

## Architecture

The application is deployed using the following Azure resources:

- **Azure Container Apps**: Hosts the Spring Boot application
- **Azure Database for PostgreSQL Flexible Server**: Persistent database storage
- **Azure Container Registry**: Stores the container image
- **Azure Key Vault**: Securely stores database credentials
- **Application Insights**: Application monitoring and logging
- **Log Analytics Workspace**: Centralized logging
- **User-Assigned Managed Identity**: Secure authentication to Azure resources

## Prerequisites

Before deploying to Azure, ensure you have:

1. **Azure CLI** (version 2.50.0 or higher)
   ```bash
   # Install Azure CLI
   # https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
   
   # Verify installation
   az --version
   ```

2. **Azure Developer CLI (azd)**
   ```bash
   # Install azd
   # https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd
   
   # Verify installation
   azd version
   ```

3. **Docker** (for building container images)
   ```bash
   # Verify Docker installation
   docker --version
   ```

4. **Azure Subscription**
   - You need an active Azure subscription
   - Login to Azure: `az login`

## Deployment Steps

### 1. Initialize the Azure Developer Environment

```bash
# Create a new environment (replace 'dev' with your preferred environment name)
azd env new petclinic-dev --no-prompt
```

### 2. Set Required Environment Variables

```bash
# Set your Azure subscription ID (get it from: az account show --query id -o tsv)
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>

# Set the Azure location (e.g., eastus, westus2, etc.)
azd env set AZURE_LOCATION eastus2

# Set PostgreSQL admin password (choose a strong password)
azd env set POSTGRES_ADMIN_PASSWORD <your-secure-password>

# Optional: Set PostgreSQL admin username (default is 'petclinicadmin')
azd env set POSTGRES_ADMIN_USER petclinicadmin
```

### 3. Create Resource Group

Since we're using resource group scoped deployment, create a resource group first:

```bash
# Set the resource group name
export AZURE_ENV_NAME="petclinic-dev"
export AZURE_LOCATION="eastus2"

# Create resource group
az group create --name "rg-${AZURE_ENV_NAME}" --location "${AZURE_LOCATION}"

# Set the resource group environment variable
azd env set AZURE_RESOURCE_GROUP "rg-${AZURE_ENV_NAME}"
```

### 4. Preview the Deployment (Optional)

```bash
# Preview what will be deployed
azd provision --preview --no-prompt
```

### 5. Deploy to Azure

```bash
# Deploy infrastructure and application
azd up --no-prompt
```

This command will:
- Provision all Azure resources defined in `infra/main.bicep`
- Build the Docker container image
- Push the image to Azure Container Registry
- Deploy the container to Azure Container Apps
- Configure all necessary connections and secrets

### 6. Access the Application

After successful deployment, azd will display the application URL. You can also get it with:

```bash
# Get the application URL
azd env get-values | grep AZURE_CONTAINER_APP_URL
```

Visit the URL in your browser to access the Spring PetClinic application.

## Post-Deployment

### View Application Logs

```bash
# View container app logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group-name> \
  --follow
```

### Monitor the Application

- Navigate to Azure Portal → Application Insights to view metrics, logs, and performance data
- Access Log Analytics Workspace for detailed log queries

### Scale the Application

```bash
# Scale the container app
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group-name> \
  --min-replicas 2 \
  --max-replicas 5
```

## Clean Up Resources

When you're done, you can delete all Azure resources:

```bash
# Delete all resources
azd down --force --no-prompt
```

## Security Notes

### Database Credentials Storage

The initial deployment stores database credentials directly in Container Apps secrets for simplicity and to avoid managed identity access issues during first deployment. 

For enhanced security in production:

1. Database credentials are also stored in Azure Key Vault
2. After initial deployment, you can switch to using Key Vault references:
   - Get the Container App's outbound IP address
   - Add it to Key Vault's network rules
   - Update Container Apps configuration to use Key Vault references
   - Set Key Vault's `defaultAction` to `Deny`

### CORS Configuration

The Container Apps ingress is configured to allow all origins (`*`) for development/demo purposes. In production environments, you should:

1. Update the Bicep template to specify allowed origins
2. Restrict CORS to only your frontend domains
3. Redeploy the infrastructure

## Troubleshooting

### Issue: PostgreSQL deployment fails with quota error

If you encounter quota issues with PostgreSQL:

1. Check available regions:
   ```bash
   az postgres flexible-server list-skus --location <location>
   ```

2. Try a different Azure region or SKU that's available

### Issue: Container Registry pull fails

Ensure the managed identity has AcrPull role:
```bash
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --scope <container-registry-id>
```

### Issue: Application can't connect to database

1. Check that firewall rules allow Azure services
2. Verify the connection string in Key Vault
3. Check container app environment variables

## Configuration

### Environment Variables

The application uses the following environment variables:

- `SPRING_PROFILES_ACTIVE`: Set to `postgres` to use PostgreSQL
- `SPRING_DATASOURCE_URL`: JDBC connection string (from Key Vault)
- `SPRING_DATASOURCE_USERNAME`: Database username (from Key Vault)
- `SPRING_DATASOURCE_PASSWORD`: Database password (from Key Vault)
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: Application Insights connection

### Database

The PostgreSQL database is configured with:
- Version: 16
- SKU: Standard_B1ms (Burstable, 1 vCore, 2 GB RAM)
- Storage: 32 GB
- Backup retention: 7 days

### Container Apps

The container app is configured with:
- CPU: 0.5 vCores
- Memory: 1 GB
- Min replicas: 1
- Max replicas: 3
- Port: 8080

## Security

The deployment follows Azure security best practices:

1. **Managed Identity**: Used for all Azure service authentication
2. **Key Vault**: Stores all sensitive credentials
3. **RBAC**: Role-based access control for all resources
4. **Network Security**: Firewall rules configured on PostgreSQL
5. **HTTPS**: Automatic HTTPS with Container Apps ingress

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Azure Database for PostgreSQL Documentation](https://learn.microsoft.com/en-us/azure/postgresql/)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Spring Boot on Azure](https://learn.microsoft.com/en-us/azure/developer/java/spring/)
