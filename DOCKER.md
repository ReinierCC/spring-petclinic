# Spring PetClinic - Containerization Guide

This document describes how to build and run the Spring PetClinic application in containers.

## Docker Setup

### Building the Docker Image

The application includes a production-ready multi-stage Dockerfile that:
- Uses Maven to build the application
- Creates a minimal runtime image with JRE 17
- Runs as a non-root user for security
- Includes health checks
- Optimized for layer caching

Build the image:

```bash
docker build -t spring-petclinic:local .
```

The build process:
1. Uses `eclipse-temurin:17-jdk-jammy` as the build stage
2. Installs Maven and compiles the application
3. Creates a runtime image with `eclipse-temurin:17-jre-jammy`
4. Copies only the compiled JAR file
5. Results in a ~399MB final image

### Running the Container

Run the application container:

```bash
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  spring-petclinic:local
```

The application will be available at: http://localhost:8080

To run with different database profiles:

```bash
# With MySQL
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e MYSQL_URL=jdbc:mysql://mysql-host:3306/petclinic \
  spring-petclinic:local

# With PostgreSQL
docker run -d \
  --name petclinic \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=postgres \
  -e POSTGRES_URL=jdbc:postgresql://postgres-host:5432/petclinic \
  spring-petclinic:local
```

### Docker Image Details

- **Base Image**: eclipse-temurin:17-jre-jammy
- **Size**: ~399MB
- **User**: Non-root (spring:spring)
- **Exposed Port**: 8080
- **Health Check**: Actuator endpoint on /actuator/health

### Viewing Logs

```bash
docker logs petclinic
```

### Stopping the Container

```bash
docker stop petclinic
docker rm petclinic
```

## Kubernetes Deployment

### Prerequisites

- kubectl installed and configured
- A Kubernetes cluster (e.g., KIND, minikube, or cloud provider)

### Using KIND (Kubernetes in Docker)

1. Create a KIND cluster:

```bash
kind create cluster --name petclinic-demo
```

2. Load the Docker image into KIND:

```bash
kind load docker-image spring-petclinic:local --name petclinic-demo
```

3. Create the namespace:

```bash
kubectl create namespace app
```

4. Deploy the application:

```bash
kubectl apply -f k8s/app-deployment.yml
```

### Kubernetes Manifests

The `k8s/app-deployment.yml` file includes:

- **Service**: ClusterIP service exposing port 80 (maps to container port 8080)
- **Deployment**: Single replica deployment with:
  - Health probes (liveness and readiness)
  - Resource limits (256Mi-512Mi memory, 250m-500m CPU)
  - H2 in-memory database profile
- **Ingress**: Optional ingress for external access

### Verifying the Deployment

Check pod status:

```bash
kubectl get pods -n app
```

Check service:

```bash
kubectl get svc -n app
```

Access the application using port-forward:

```bash
kubectl port-forward -n app svc/petclinic 8080:80
```

Then open: http://localhost:8080

### Viewing Logs in Kubernetes

```bash
kubectl logs -n app -l app=petclinic
```

### Scaling the Application

```bash
kubectl scale deployment petclinic -n app --replicas=3
```

## Health Checks

The application exposes Spring Boot Actuator endpoints:

- Health: http://localhost:8080/actuator/health
- Liveness: http://localhost:8080/actuator/health/liveness
- Readiness: http://localhost:8080/actuator/health/readiness

## Database Options

By default, the application uses an H2 in-memory database. For production deployments:

1. **MySQL**: Create similar Kubernetes manifests for MySQL (refer to docker-compose.yml for configuration)
2. **PostgreSQL**: Deploy using `k8s/db.yml` (PostgreSQL deployment) and update the application deployment to use the `postgres` profile

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs petclinic
```

### Image build fails

Ensure you have:
- Docker installed and running
- Java 17 or later
- Internet connection for Maven dependencies

### Kubernetes pod in ImagePullBackOff

When using KIND:
1. Ensure image is loaded: `kind load docker-image spring-petclinic:local --name petclinic-demo`
2. Verify image in cluster: `docker exec petclinic-demo-control-plane crictl images | grep petclinic`
3. Check pod events: `kubectl describe pod -n app <pod-name>`

## Security Features

- Non-root user in container (UID/GID for `spring` user)
- Minimal runtime image (JRE only, no build tools)
- Health checks for container orchestration
- No secrets in image (use environment variables or Kubernetes secrets)

## Performance Optimization

The Dockerfile includes several optimizations:
- Multi-stage build to reduce image size
- Layer caching for dependencies
- Separate dependency download step
- SSL workarounds for build-time Maven downloads (Note: These are required due to environment-specific certificate issues. In production environments, ensure proper SSL certificates are configured)

## Additional Resources

- [Spring PetClinic GitHub](https://github.com/spring-projects/spring-petclinic)
- [Spring Boot Docker Documentation](https://spring.io/guides/topicals/spring-boot-docker/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [KIND Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
