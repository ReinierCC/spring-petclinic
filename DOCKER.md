# Build instructions for containerized Spring PetClinic

## Prerequisites
- Docker installed
- Java 17 or newer (for local builds)

## Building the Docker Image

### Option 1: Simple Dockerfile (requires pre-built JAR)

1. Build the JAR file:
```bash
./mvnw clean package -DskipTests
```

2. Build the Docker image:
```bash
docker build -t spring-petclinic:latest .
```

3. Run the container:
```bash
docker run -p 8080:8080 spring-petclinic:latest
```

### Option 2: Multi-stage Dockerfile (builds from source)

Use the multi-stage Dockerfile that builds the application inside Docker:

```bash
docker build -f Dockerfile.multistage -t spring-petclinic:latest .
```

Note: This requires network access to Maven Central repository.

### Option 3: Using Spring Boot Build Plugin (recommended by Spring Boot)

```bash
./mvnw spring-boot:build-image
```

This creates an OCI image using Cloud Native Buildpacks.

## Running the Application

### Run standalone:
```bash
docker run -p 8080:8080 spring-petclinic:latest
```

### Run with MySQL using docker-compose:
```bash
docker-compose up
```

### Run with PostgreSQL using docker-compose:
```bash
docker-compose up postgres
```

## Accessing the Application

- Application: http://localhost:8080
- Health Check: http://localhost:8080/actuator/health
- H2 Console (default): http://localhost:8080/h2-console

## Kubernetes Deployment

Kubernetes manifests are available in the `k8s/` directory:

```bash
kubectl apply -f k8s/db.yml
kubectl apply -f k8s/petclinic.yml
```

**Note**: The default `k8s/petclinic.yml` uses `dsyer/petclinic` as the image. To use your locally built image:

1. Tag your image appropriately:
```bash
docker tag spring-petclinic:latest <your-registry>/spring-petclinic:latest
docker push <your-registry>/spring-petclinic:latest
```

2. Update the image reference in `k8s/petclinic.yml`:
```yaml
image: <your-registry>/spring-petclinic:latest
```

Or create a local Kubernetes deployment using kind or minikube and load the image directly.

## Environment Variables

- `SPRING_PROFILES_ACTIVE`: Set to `mysql` or `postgres` to use respective database
- `SPRING_DATASOURCE_URL`: Custom database URL
- `SPRING_DATASOURCE_USERNAME`: Database username
- `SPRING_DATASOURCE_PASSWORD`: Database password

## Security Considerations

- The image runs as a non-root user (`spring:spring`)
- Health checks are configured
- Minimal runtime image based on `eclipse-temurin:17-jre-jammy`
- Consider scanning images with tools like Trivy before deploying to production
