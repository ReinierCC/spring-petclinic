#!/bin/bash

# Deploy Spring PetClinic Infrastructure to Azure
# This script provisions all required Azure resources using Bicep

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-petclinic-dev}"
LOCATION="${LOCATION:-eastus}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
POSTGRES_ADMIN_USERNAME="${POSTGRES_ADMIN_USERNAME:-petclinicadmin}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD:-P@ssw0rd$(openssl rand -base64 12)}"

print_info "Starting Azure infrastructure deployment..."
print_info "Resource Group: $RESOURCE_GROUP_NAME"
print_info "Location: $LOCATION"
print_info "Environment: $ENVIRONMENT_NAME"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    print_info "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
print_info "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group if it doesn't exist
print_info "Creating resource group '$RESOURCE_GROUP_NAME' in location '$LOCATION'..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --output table

# Deploy infrastructure using Bicep
print_info "Deploying Azure infrastructure using Bicep template..."
DEPLOYMENT_NAME="petclinic-infra-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file ./infra/main.bicep \
    --parameters environmentName="$ENVIRONMENT_NAME" \
    --parameters postgresAdminUsername="$POSTGRES_ADMIN_USERNAME" \
    --parameters postgresAdminPassword="$POSTGRES_ADMIN_PASSWORD" \
    --output table

# Get deployment outputs
print_info "Retrieving deployment outputs..."
AKS_CLUSTER_NAME=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.aksClusterName.value -o tsv)

ACR_NAME=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.acrName.value -o tsv)

ACR_LOGIN_SERVER=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.acrLoginServer.value -o tsv)

POSTGRES_SERVER_FQDN=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.postgresServerFqdn.value -o tsv)

KEY_VAULT_NAME=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.keyVaultName.value -o tsv)

MANAGED_IDENTITY_CLIENT_ID=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.managedIdentityClientId.value -o tsv)

# Save deployment information to file
DEPLOYMENT_INFO_FILE=".azure/deployment-info.env"
print_info "Saving deployment information to $DEPLOYMENT_INFO_FILE..."
mkdir -p .azure
cat > "$DEPLOYMENT_INFO_FILE" << EOF
# Azure Deployment Information
# Generated on $(date)

RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME
LOCATION=$LOCATION
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AKS_CLUSTER_NAME=$AKS_CLUSTER_NAME
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
POSTGRES_SERVER_FQDN=$POSTGRES_SERVER_FQDN
POSTGRES_ADMIN_USERNAME=$POSTGRES_ADMIN_USERNAME
POSTGRES_ADMIN_PASSWORD=$POSTGRES_ADMIN_PASSWORD
KEY_VAULT_NAME=$KEY_VAULT_NAME
MANAGED_IDENTITY_CLIENT_ID=$MANAGED_IDENTITY_CLIENT_ID
EOF

print_info "================================"
print_info "Infrastructure deployment completed successfully!"
print_info "================================"
print_info "Resource Group: $RESOURCE_GROUP_NAME"
print_info "AKS Cluster: $AKS_CLUSTER_NAME"
print_info "Container Registry: $ACR_LOGIN_SERVER"
print_info "PostgreSQL Server: $POSTGRES_SERVER_FQDN"
print_info "Key Vault: $KEY_VAULT_NAME"
print_info "================================"
print_info "Deployment information saved to: $DEPLOYMENT_INFO_FILE"
print_warning "IMPORTANT: Keep the deployment-info.env file secure as it contains sensitive information!"
print_info "================================"
print_info "Next steps:"
print_info "1. Run './scripts/deploy-app.sh' to build and deploy the application"
EOF

chmod +x "$DEPLOYMENT_INFO_FILE" 2>/dev/null || true
