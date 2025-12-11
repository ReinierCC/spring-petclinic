#!/bin/bash

# Script to validate Azure Bicep templates

set -e

echo "🔍 Validating Azure Bicep templates..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    echo "   Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo "✅ Azure CLI found"

# Navigate to infra directory
cd "$(dirname "$0")/../infra"

# Validate main.bicep
echo ""
echo "📋 Validating main.bicep..."
az bicep build --file main.bicep

if [ $? -eq 0 ]; then
    echo "✅ main.bicep is valid"
else
    echo "❌ main.bicep has errors"
    exit 1
fi

# Validate individual modules
echo ""
echo "📋 Validating core modules..."

modules=(
    "core/monitor/monitoring.bicep"
    "core/host/container-registry.bicep"
    "core/host/container-apps-environment.bicep"
    "core/host/container-app.bicep"
    "core/database/postgresql/flexible-server.bicep"
    "core/security/key-vault.bicep"
    "core/security/key-vault-access.bicep"
    "core/security/key-vault-secret.bicep"
    "core/security/registry-access.bicep"
    "core/identity/user-assigned-managed-identity.bicep"
)

for module in "${modules[@]}"; do
    echo "  Validating $module..."
    az bicep build --file "$module"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ $module is valid"
    else
        echo "  ❌ $module has errors"
        exit 1
    fi
done

echo ""
echo "🎉 All Bicep templates are valid!"
echo ""
echo "Next steps:"
echo "  1. Install Azure Developer CLI: https://aka.ms/azd-install"
echo "  2. Login: azd auth login"
echo "  3. Deploy: azd up"
