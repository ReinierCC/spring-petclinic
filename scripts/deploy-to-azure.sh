#!/bin/bash

# Quick deployment script for Azure

set -e

echo "🚀 Spring PetClinic - Azure Deployment Script"
echo "=============================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed."
    echo "   Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI (azd) is not installed."
    echo "   Install from: https://aka.ms/azd-install"
    exit 1
fi

echo "✅ Prerequisites met"
echo ""

# Check if logged in
echo "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Logging in..."
    az login
fi

if ! azd auth login --check-status &> /dev/null; then
    echo "Not logged in to Azure Developer CLI. Logging in..."
    azd auth login
fi

echo "✅ Authenticated"
echo ""

# Get or create environment
if [ -z "$AZURE_ENV_NAME" ]; then
    read -p "Enter environment name (e.g., petclinic-prod): " AZURE_ENV_NAME
    export AZURE_ENV_NAME
fi

echo "Environment: $AZURE_ENV_NAME"

# Check if environment exists
if ! azd env list | grep -q "$AZURE_ENV_NAME"; then
    echo "Creating new environment: $AZURE_ENV_NAME"
    azd env new "$AZURE_ENV_NAME"
else
    echo "Using existing environment: $AZURE_ENV_NAME"
    azd env select "$AZURE_ENV_NAME"
fi

# Set required variables
if [ -z "$(azd env get-value AZURE_SUBSCRIPTION_ID)" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    echo "Setting subscription ID: $SUBSCRIPTION_ID"
    azd env set AZURE_SUBSCRIPTION_ID "$SUBSCRIPTION_ID"
fi

if [ -z "$(azd env get-value AZURE_LOCATION)" ]; then
    read -p "Enter Azure region [eastus]: " AZURE_LOCATION
    AZURE_LOCATION=${AZURE_LOCATION:-eastus}
    azd env set AZURE_LOCATION "$AZURE_LOCATION"
fi

if [ -z "$(azd env get-value POSTGRES_ADMIN_PASSWORD)" ]; then
    read -sp "Enter PostgreSQL admin password: " POSTGRES_ADMIN_PASSWORD
    echo ""
    azd env set POSTGRES_ADMIN_PASSWORD "$POSTGRES_ADMIN_PASSWORD"
fi

echo ""
echo "Configuration complete!"
echo ""
echo "Deploying to Azure..."
echo "This may take 10-15 minutes..."
echo ""

# Deploy
azd up --no-prompt

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "To view your application:"
echo "  1. Check the URL printed above"
echo "  2. Or run: azd show"
echo ""
echo "To view logs:"
echo "  azd monitor --logs"
