# Azure Kubernetes Service (AKS) Deployment Guide

This guide provides step-by-step instructions for deploying the Spring PetClinic application to Azure Kubernetes Service (AKS).

## Architecture Overview

The deployment consists of the following Azure resources:

- **Azure Kubernetes Service (AKS)**: Hosts the containerized Spring PetClinic application
- **Azure Container Registry (ACR)**: Stores Docker container images
- **Azure Database for PostgreSQL Flexible Server**: Provides managed database service
- **Azure Key Vault**: Securely stores database credentials and sensitive configuration
- **Application Insights**: Monitors application performance and collects telemetry
- **Log Analytics Workspace**: Centralized logging for all services
- **User-Assigned Managed Identity**: Enables secure access to Azure resources without credentials

## Prerequisites

Before you begin, ensure you have the following installed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (version 2.50.0 or later)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (Kubernetes command-line tool)
- [Docker](https://docs.docker.com/get-docker/) (for local testing)
- [Java 17 or later](https://adoptium.net/)
- [Maven](https://maven.apache.org/download.cgi) (or use the included Maven wrapper)
- An active Azure subscription

## Quick Start

### 1. Login to Azure

```bash
az login
```

Set your subscription (if you have multiple):

```bash
az account set --subscription "Your Subscription Name"
```

### 2. Provision Azure Infrastructure

Run the provisioning script to create all required Azure resources:

```bash
./scripts/provision-azure.sh
```

This script will:
- Create a resource group
- Deploy all Azure resources using Bicep templates
- Save deployment information to `.azure/deployment-info.env`

You can customize the deployment by setting environment variables:

```bash
export RESOURCE_GROUP_NAME="rg-petclinic-prod"
export LOCATION="westus2"
export ENVIRONMENT_NAME="prod"
./scripts/provision-azure.sh
```

### 3. Deploy the Application

After infrastructure is provisioned, deploy the application:

```bash
./scripts/deploy-app.sh
```

This script will:
- Build the Docker image
- Push the image to Azure Container Registry
- Deploy the application to AKS
- Create Kubernetes secrets from Key Vault
- Display the application URL

### 4. Access the Application

Once deployed, the script will output the application URL. You can also get it manually:

```bash
kubectl get service petclinic -n petclinic
```

Access the application at `http://<EXTERNAL-IP>`

## Manual Deployment Steps

If you prefer to deploy manually or need more control:

### Step 1: Create Resource Group

```bash
RESOURCE_GROUP="rg-petclinic-dev"
LOCATION="eastus"

az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Step 2: Deploy Infrastructure with Bicep

```bash
az deployment group create \
  --name petclinic-infra \
  --resource-group $RESOURCE_GROUP \
  --template-file ./infra/main.bicep \
  --parameters environmentName=dev \
  --parameters postgresAdminUsername=petclinicadmin \
  --parameters postgresAdminPassword='YourSecurePassword123!'
```

### Step 3: Get Deployment Outputs

```bash
ACR_NAME=$(az deployment group show -n petclinic-infra -g $RESOURCE_GROUP --query properties.outputs.acrName.value -o tsv)
AKS_CLUSTER_NAME=$(az deployment group show -n petclinic-infra -g $RESOURCE_GROUP --query properties.outputs.aksClusterName.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment group show -n petclinic-infra -g $RESOURCE_GROUP --query properties.outputs.acrLoginServer.value -o tsv)
KEY_VAULT_NAME=$(az deployment group show -n petclinic-infra -g $RESOURCE_GROUP --query properties.outputs.keyVaultName.value -o tsv)
```

### Step 4: Build and Push Docker Image

```bash
# Build the image
docker build -t petclinic:latest .

# Tag for ACR
docker tag petclinic:latest $ACR_LOGIN_SERVER/petclinic:latest

# Login to ACR
az acr login --name $ACR_NAME

# Push to ACR
docker push $ACR_LOGIN_SERVER/petclinic:latest
```

### Step 5: Get AKS Credentials

```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

### Step 6: Create Kubernetes Secrets

```bash
# Get database credentials from Key Vault
POSTGRES_URL=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name postgres-connection-string --query value -o tsv)
POSTGRES_USER=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name postgres-username --query value -o tsv)
POSTGRES_PASS=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name postgres-password --query value -o tsv)

# Create namespace
kubectl create namespace petclinic

# Create secret
kubectl create secret generic postgres-secret \
  --from-literal=SPRING_DATASOURCE_URL="$POSTGRES_URL" \
  --from-literal=SPRING_DATASOURCE_USERNAME="$POSTGRES_USER" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="$POSTGRES_PASS" \
  --namespace=petclinic
```

### Step 7: Deploy to AKS

```bash
# Update manifest with ACR login server
sed "s|ACR_LOGIN_SERVER|$ACR_LOGIN_SERVER|g" k8s/petclinic-aks.yml | kubectl apply -f -
```

### Step 8: Verify Deployment

```bash
# Check pods
kubectl get pods -n petclinic

# Check service
kubectl get service petclinic -n petclinic

# View logs
kubectl logs -l app=petclinic -n petclinic --tail=100
```

## CI/CD with GitHub Actions

The repository includes a GitHub Actions workflow for automated deployment.

### Setup

1. Create a service principal with contributor access:

```bash
az ad sp create-for-rbac --name "petclinic-github-actions" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
  --sdk-auth
```

2. Add the following secrets to your GitHub repository:
   - `AZURE_CLIENT_ID`: Client ID from the service principal
   - `AZURE_TENANT_ID`: Tenant ID from the service principal
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

3. The workflow will automatically trigger on pushes to the main branch or can be triggered manually.

## Monitoring and Logging

### Application Insights

View application metrics and telemetry:

```bash
az monitor app-insights component show \
  --app appi-petclinic-dev \
  --resource-group $RESOURCE_GROUP
```

### AKS Logs

View container logs:

```bash
# Stream logs from all pods
kubectl logs -f -l app=petclinic -n petclinic

# View logs from a specific pod
kubectl logs <pod-name> -n petclinic
```

### Azure Monitor

Access logs in Azure Portal:
1. Navigate to your AKS cluster
2. Go to "Logs" under Monitoring
3. Run queries using Kusto Query Language (KQL)

Example query for container logs:
```kql
ContainerLog
| where Namespace == "petclinic"
| order by TimeGenerated desc
| take 100
```

## Scaling

### Manual Scaling

Scale the deployment:

```bash
kubectl scale deployment petclinic --replicas=5 -n petclinic
```

Scale the AKS node pool:

```bash
az aks scale \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 3 \
  --nodepool-name agentpool
```

### Auto-scaling

Enable horizontal pod autoscaling:

```bash
kubectl autoscale deployment petclinic \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n petclinic
```

## Troubleshooting

### Pods not starting

Check pod status and events:

```bash
kubectl describe pod <pod-name> -n petclinic
kubectl get events -n petclinic --sort-by='.lastTimestamp'
```

### Database connection issues

Verify PostgreSQL firewall rules allow AKS:

```bash
az postgres flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name <postgres-server-name>
```

### Image pull errors

Ensure AKS has permission to pull from ACR:

```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --attach-acr $ACR_NAME
```

## Clean Up

To delete all resources:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Security Best Practices

1. **Use managed identities** instead of service principals when possible
2. **Enable RBAC** on AKS cluster
3. **Use Azure Key Vault** for storing secrets
4. **Enable SSL/TLS** for PostgreSQL connections
5. **Use private endpoints** for production workloads
6. **Regularly update** AKS cluster and node images
7. **Implement network policies** to restrict pod-to-pod communication
8. **Enable Azure Policy** for compliance

## Cost Optimization

- Use **Burstable VM SKUs** for non-production environments
- Enable **cluster autoscaler** to scale nodes based on demand
- Use **Azure Reserved Instances** for production workloads
- Stop non-production environments during off-hours
- Monitor costs with **Azure Cost Management**

## Additional Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Azure Database for PostgreSQL Documentation](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Spring Boot on Azure](https://docs.microsoft.com/en-us/azure/developer/java/spring-framework/)

## Support

For issues or questions:
- Check the [GitHub Issues](https://github.com/ReinierCC/spring-petclinic/issues)
- Review [Spring PetClinic Documentation](../README.md)
- Consult [Azure Support](https://azure.microsoft.com/en-us/support/)
