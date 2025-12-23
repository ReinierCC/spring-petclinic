# Spring Petclinic Containerization Guide

## Overview
This document describes the containerization approach for the Spring Petclinic application.

## Dockerfile Details

### Location
`Dockerfile` in the repository root

### Approach
The Dockerfile uses a **pre-built JAR approach**, which is ideal for CI/CD pipelines where the application is built separately from the Docker image creation.

### Key Features
1. **Base Image**: `eclipse-temurin:17-jre-jammy` - Official Eclipse Temurin JRE 17
2. **Non-root User**: Application runs as user `spring` (not root) for security
3. **Health Check**: Configured to use Spring Boot Actuator `/actuator/health` endpoint
4. **Port**: Exposes port 8080
5. **Minimal Dependencies**: Only installs `wget` for health checks

### Security Score
- **Grade**: A (90/100)
- **Non-root user**: ✓ Implemented
- **Health check**: ✓ Implemented  
- **Minimal base image**: ✓ Using JRE instead of JDK

## Building the Image

### Prerequisites
1. Build the JAR file first:
```bash
./mvnw clean package -DskipTests
```

### Build Docker Image
```bash
docker build -t spring-petclinic:1.0 .
```

## Running the Container

### Basic Run
```bash
docker run -d -p 8080:8080 --name petclinic spring-petclinic:1.0
```

### Access the Application
- **Main Application**: http://localhost:8080/
- **Health Check**: http://localhost:8080/actuator/health
- **Actuator Endpoints**: http://localhost:8080/actuator

### Stop the Container
```bash
docker stop petclinic
docker rm petclinic
```

## Image Details

- **Image Name**: spring-petclinic:1.0
- **Image Size**: ~399MB
- **Base Image**: eclipse-temurin:17-jre-jammy
- **User**: spring (non-root)
- **Working Directory**: /app

## Health Check Configuration

The Dockerfile includes a health check that:
- Runs every 30 seconds
- Times out after 3 seconds
- Allows 30 seconds for startup
- Retries up to 3 times

## Environment Variables

The application uses default Spring Boot configuration. You can override any Spring properties using environment variables:

```bash
docker run -d -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://host:3306/petclinic \
  spring-petclinic:1.0
```

## Alternative: Spring Boot Buildpacks

Spring Boot also supports building images using Cloud Native Buildpacks:

```bash
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=spring-petclinic:1.0
```

This approach automatically creates an optimized container image without needing a Dockerfile.

## Verification

Verify the container is running and healthy:

```bash
# Check container status
docker ps

# Check logs
docker logs petclinic

# Test health endpoint
curl http://localhost:8080/actuator/health

# Test main page
curl http://localhost:8080/
```

## Production Considerations

1. **Database**: Configure external database (MySQL/PostgreSQL) instead of in-memory H2
2. **Secrets**: Use Docker secrets or environment variables for sensitive data
3. **Logging**: Configure appropriate logging levels and log aggregation
4. **Monitoring**: Enable additional actuator endpoints for monitoring
5. **Resource Limits**: Set memory and CPU limits in production deployments
6. **Registry**: Tag and push to a container registry for deployment

Example with resource limits:
```bash
docker run -d \
  -p 8080:8080 \
  --name petclinic \
  --memory="512m" \
  --cpus="1.0" \
  spring-petclinic:1.0
```
