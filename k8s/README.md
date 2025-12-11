# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying the Spring PetClinic application to a Kubernetes cluster.

## Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured to connect to your cluster
- Docker image of the PetClinic application

## Building the Docker Image

Before deploying to Kubernetes, you need to build and push the Docker image:

```bash
# Build the application
./mvnw package -DskipTests

# Build the Docker image
docker build -t <your-registry>/spring-petclinic:latest .

# Push to your registry (DockerHub, GCR, ECR, etc.)
docker push <your-registry>/spring-petclinic:latest
```

## Update the Image Reference

Update the image reference in `petclinic.yml` to point to your registry:

```yaml
image: <your-registry>/spring-petclinic:latest
```

## Deployment

### Deploy PostgreSQL Database

```bash
kubectl apply -f db.yml
```

This creates:
- A Secret with database credentials
- A PostgreSQL Service
- A PostgreSQL Deployment

### Deploy PetClinic Application

```bash
kubectl apply -f petclinic.yml
```

This creates:
- A Service (NodePort) exposing the application
- A Deployment with the PetClinic application

### Verify Deployment

```bash
# Check pods are running
kubectl get pods

# Check services
kubectl get services

# Get the NodePort
kubectl get service petclinic
```

## Accessing the Application

### Using NodePort (local/on-premise cluster)

```bash
# Get the node IP and port
kubectl get nodes -o wide
kubectl get service petclinic

# Access at http://<node-ip>:<node-port>
```

### Using Port Forwarding (local development)

```bash
kubectl port-forward service/petclinic 8080:80

# Access at http://localhost:8080
```

### Using LoadBalancer (cloud cluster)

Change the service type in `petclinic.yml` from `NodePort` to `LoadBalancer`:

```yaml
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
```

Then get the external IP:

```bash
kubectl get service petclinic
```

## Health Checks

The application includes health checks:
- Liveness probe: `/livez`
- Readiness probe: `/readyz`

## Database Configuration

The application connects to PostgreSQL using Spring Boot's service binding support. The database connection details are provided via the `demo-db` Secret mounted at `/bindings/secret`.

## Cleanup

```bash
kubectl delete -f petclinic.yml
kubectl delete -f db.yml
```

## Customization

### Scaling

Adjust the number of replicas in `petclinic.yml`:

```yaml
spec:
  replicas: 3
```

### Database Profile

The application uses the `postgres` profile. To use H2 in-memory database instead, remove or change the `SPRING_PROFILES_ACTIVE` environment variable.

### Resource Limits

Add resource limits to prevent resource exhaustion:

```yaml
resources:
  limits:
    cpu: "1"
    memory: "512Mi"
  requests:
    cpu: "500m"
    memory: "256Mi"
```
