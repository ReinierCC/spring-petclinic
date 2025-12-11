#!/bin/bash

# Deploy Spring PetClinic Application to AKS
# This script builds the Docker image, pushes it to ACR, and deploys to AKS

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

# Load deployment information
DEPLOYMENT_INFO_FILE=".azure/deployment-info.env"
if [ ! -f "$DEPLOYMENT_INFO_FILE" ]; then
    print_error "Deployment information file not found: $DEPLOYMENT_INFO_FILE"
    print_info "Please run './scripts/provision-azure.sh' first to create the infrastructure."
    exit 1
fi

print_info "Loading deployment information from $DEPLOYMENT_INFO_FILE..."
source "$DEPLOYMENT_INFO_FILE"

# Configuration
IMAGE_NAME="petclinic"
IMAGE_TAG="${IMAGE_TAG:-latest}"

print_info "Starting application deployment..."
print_info "Resource Group: $RESOURCE_GROUP_NAME"
print_info "AKS Cluster: $AKS_CLUSTER_NAME"
print_info "ACR: $ACR_LOGIN_SERVER"
print_info "Image: $IMAGE_NAME:$IMAGE_TAG"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

# Build Docker image
print_info "Building Docker image..."
docker build -t "$IMAGE_NAME:$IMAGE_TAG" .

# Tag image for ACR
print_info "Tagging image for ACR..."
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# Login to ACR
print_info "Logging in to Azure Container Registry..."
az acr login --name "$ACR_NAME"

# Push image to ACR
print_info "Pushing image to ACR..."
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# Get AKS credentials
print_info "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Get PostgreSQL connection details from Key Vault
print_info "Retrieving database credentials from Key Vault..."
POSTGRES_CONNECTION_STRING=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-connection-string" \
    --query value -o tsv)

POSTGRES_USERNAME=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-username" \
    --query value -o tsv)

POSTGRES_PASSWORD=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-password" \
    --query value -o tsv)

# Create namespace if it doesn't exist
print_info "Creating Kubernetes namespace..."
kubectl create namespace petclinic --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secret for database
print_info "Creating Kubernetes secret for database credentials..."
kubectl create secret generic postgres-secret \
    --from-literal=SPRING_DATASOURCE_URL="$POSTGRES_CONNECTION_STRING" \
    --from-literal=SPRING_DATASOURCE_USERNAME="$POSTGRES_USERNAME" \
    --from-literal=SPRING_DATASOURCE_PASSWORD="$POSTGRES_PASSWORD" \
    --namespace=petclinic \
    --dry-run=client -o yaml | kubectl apply -f -

# Update Kubernetes manifest with ACR login server
print_info "Updating Kubernetes manifests with ACR login server..."
sed "s|ACR_LOGIN_SERVER|$ACR_LOGIN_SERVER|g" k8s/petclinic-aks.yml > /tmp/petclinic-aks-updated.yml

# Deploy to AKS
print_info "Deploying application to AKS..."
kubectl apply -f /tmp/petclinic-aks-updated.yml

# Wait for deployment to be ready
print_info "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/petclinic -n petclinic || true

# Get service external IP
print_info "Waiting for LoadBalancer to assign external IP..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' --timeout=300s service/petclinic -n petclinic || true

EXTERNAL_IP=$(kubectl get service petclinic -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get deployment status
print_info "================================"
print_info "Deployment Status:"
print_info "================================"
kubectl get pods -n petclinic
echo ""
kubectl get services -n petclinic
echo ""

if [ -n "$EXTERNAL_IP" ]; then
    print_info "================================"
    print_info "Application deployed successfully!"
    print_info "================================"
    print_info "Access the application at: http://$EXTERNAL_IP"
    print_info "================================"
    
    # Save application URL
    echo "APPLICATION_URL=http://$EXTERNAL_IP" >> "$DEPLOYMENT_INFO_FILE"
else
    print_warning "External IP not yet assigned. Run the following command to check:"
    print_warning "kubectl get service petclinic -n petclinic"
fi

print_info "Deployment completed!"
