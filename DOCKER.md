# Docker Instructions for Spring PetClinic

## Building the Application

Before building the Docker image, you need to build the JAR file:

```bash
./mvnw package -DskipTests -B
```

## Building the Docker Image

```bash
docker build -t spring-petclinic:local .
```

## Running the Containerized Application

Run the application with:

```bash
docker run -d -p 8080:8080 --name petclinic spring-petclinic:local
```

Access the application at: http://localhost:8080

## Health Check

Check the application health:

```bash
curl http://localhost:8080/actuator/health
```

## Stopping the Container

```bash
docker stop petclinic
docker rm petclinic
```

## Image Details

- **Base Image**: eclipse-temurin:17-jre-jammy (JRE 17)
- **Image Size**: ~399MB
- **Non-root User**: Runs as user `spring` for security
- **Health Check**: Built-in health check using Spring Boot Actuator
- **Port**: 8080

## Multi-stage Build

The Dockerfile uses a multi-stage build pattern:
1. **Builder stage**: Uses Maven base image to prepare the JAR file
2. **Runtime stage**: Uses minimal JRE image to run the application

This approach keeps the final image size small and secure.
