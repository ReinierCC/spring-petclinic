# Docker & Kubernetes Deployment Guide

This guide explains how to build and deploy the Spring PetClinic application using Docker and Kubernetes.

## Prerequisites

- Docker
- Kubernetes cluster (e.g., KIND, minikube, or production cluster)
- kubectl CLI tool

## Building the Docker Image

1. First, build the application JAR:
   ```bash
   ./gradlew clean bootJar --no-daemon
   ```

2. Build the Docker image:
   ```bash
   docker build -t spring-petclinic:1.0 .
   ```

   The image will be approximately 400MB and uses:
   - Base: eclipse-temurin:17-jre-jammy
   - Non-root user: petclinic
   - Exposed port: 8080
   - Health check: /actuator/health

## Running with Docker

Run the container locally:
```bash
docker run -d -p 8080:8080 --name petclinic spring-petclinic:1.0
```

Access the application at: http://localhost:8080

To stop:
```bash
docker stop petclinic
docker rm petclinic
```

## Deploying to Kubernetes

### For KIND (Kubernetes in Docker)

1. Create a KIND cluster:
   ```bash
   kind create cluster --name kind
   ```

2. Load the image into KIND:
   ```bash
   kind load docker-image spring-petclinic:1.0 --name kind
   ```

3. Deploy to Kubernetes:
   ```bash
   kubectl apply -f k8s/deployment.yml
   ```

4. Verify the deployment:
   ```bash
   kubectl get pods -n app
   kubectl get svc -n app
   ```

5. Access the application via port-forward:
   ```bash
   kubectl port-forward -n app svc/spring-petclinic 8080:80
   ```

   Then open: http://localhost:8080

### For Other Kubernetes Clusters

1. Tag and push the image to your registry:
   ```bash
   docker tag spring-petclinic:1.0 YOUR_REGISTRY/spring-petclinic:1.0
   docker push YOUR_REGISTRY/spring-petclinic:1.0
   ```

2. Update the image reference in `k8s/deployment.yml`:
   ```yaml
   image: YOUR_REGISTRY/spring-petclinic:1.0
   imagePullPolicy: Always  # Change from Never
   ```

3. Deploy:
   ```bash
   kubectl apply -f k8s/deployment.yml
   ```

## Architecture

- **Namespace**: app
- **Service**: spring-petclinic (ClusterIP, port 80 → 8080)
- **Deployment**: spring-petclinic (1 replica)
- **Resources**:
  - Requests: 512Mi memory, 500m CPU
  - Limits: 1Gi memory, 1000m CPU

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n app
kubectl describe pod -n app <pod-name>
kubectl logs -n app <pod-name>
```

### Access the application
```bash
# Port-forward method
kubectl port-forward -n app svc/spring-petclinic 8080:80

# Or using pod directly
kubectl port-forward -n app <pod-name> 8080:8080
```

### Health checks
The application exposes actuator endpoints:
- Health: http://localhost:8080/actuator/health
- All actuator endpoints: http://localhost:8080/actuator

## Clean Up

### Docker
```bash
docker stop petclinic
docker rm petclinic
docker rmi spring-petclinic:1.0
```

### Kubernetes
```bash
kubectl delete -f k8s/deployment.yml
```

### KIND Cluster
```bash
kind delete cluster --name kind
```
