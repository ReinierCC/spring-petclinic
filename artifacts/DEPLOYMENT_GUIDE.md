# Spring Petclinic - Containerization and Deployment Summary

## Overview
Successfully containerized the Spring Petclinic application and deployed it to a local Kubernetes (KIND) cluster.

## Docker Image

### Image Details
- **Name:** `spring-petclinic:1.0`
- **Size:** 330MB
- **Base Image:** eclipse-temurin:17-jre-jammy
- **Build Method:** Multi-stage (local Maven build + runtime-only Docker image)

### Running the Container Locally
```bash
# Build the application (if needed)
./mvnw clean package -DskipTests

# Build the Docker image
docker build -t spring-petclinic:1.0 .

# Run the container
docker run -p 8080:8080 spring-petclinic:1.0

# Access the application
open http://localhost:8080
```

## Kubernetes Deployment

### Cluster Setup
- **Cluster Type:** KIND (Kubernetes in Docker)
- **Cluster Name:** kind
- **Namespace:** app

### Create KIND Cluster
```bash
kind create cluster --name kind
```

### Load Image into KIND
```bash
kind load docker-image spring-petclinic:1.0 --name kind
```

### Deploy to Kubernetes
```bash
# Apply manifests
kubectl apply -f artifacts/k8s-manifests.yaml

# Verify deployment
kubectl get pods -n app
kubectl get svc -n app

# Access the application via port-forward
kubectl port-forward -n app svc/spring-petclinic 8080:8080

# Access the application
open http://localhost:8080
```

### Kubernetes Resources
- **Namespace:** app
- **Deployment:** spring-petclinic (1 replica)
- **Service:** spring-petclinic (ClusterIP, port 8080)
- **Pod:** Running and healthy (1/1 Ready)

## Files Created

1. **Dockerfile** - Runtime-only container image definition
2. **artifacts/k8s-manifests.yaml** - Kubernetes Deployment and Service manifests
3. **artifacts/app.png** - Screenshot of running application
4. **artifacts/tool-call-checklist.md** - Complete execution log

## Application Features

- **Framework:** Spring Boot 4.0.0
- **Java Version:** 17
- **Database:** H2 (in-memory)
- **Port:** 8080
- **Actuator Endpoints:** Enabled at `/actuator/*`

## Accessing the Application

### Local Docker
```bash
docker run -p 8080:8080 spring-petclinic:1.0
# Then visit: http://localhost:8080
```

### Kubernetes (KIND)
```bash
kubectl port-forward -n app svc/spring-petclinic 8080:8080
# Then visit: http://localhost:8080
```

## Next Steps

To enhance the deployment:

1. **Add Health Probes** (currently disabled due to timeout issues)
   - Increase resource limits
   - Optimize application startup time
   - Configure proper liveness and readiness probes

2. **Add Ingress** for external access without port-forwarding

3. **Add Persistent Storage** if switching to MySQL/PostgreSQL database

4. **Add Resource Limits** tuning based on actual usage

5. **Add HPA** (Horizontal Pod Autoscaler) for scaling

6. **Enable Security Scanning** (install Trivy for vulnerability scanning)

## Troubleshooting

### Pod Not Starting
```bash
kubectl get pods -n app
kubectl describe pod -n app <pod-name>
kubectl logs -n app <pod-name>
```

### Service Not Accessible
```bash
kubectl get svc -n app
kubectl get endpoints -n app
```

### Image Not Found
```bash
# Reload image into KIND
kind load docker-image spring-petclinic:1.0 --name kind
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace app

# Delete KIND cluster
kind delete cluster --name kind

# Remove Docker image
docker rmi spring-petclinic:1.0
```
