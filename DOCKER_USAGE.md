# Docker Usage Guide for Spring PetClinic

This guide explains how to build and run the Spring PetClinic application using Docker.

## Quick Start

### Build and Run (Default H2 Database)

```bash
# Build the JAR
./mvnw clean package -DskipTests

# Build Docker image
docker build -t spring-petclinic:latest .

# Run the container
docker run -d -p 8080:8080 --name petclinic spring-petclinic:latest

# Access the application
open http://localhost:8080
```

### Check Container Status

```bash
# View logs
docker logs petclinic

# Check health
curl http://localhost:8080/actuator/health

# View running containers
docker ps
```

### Stop and Remove

```bash
docker stop petclinic
docker rm petclinic
```

---

## Running with External Database

### Using MySQL

1. Start MySQL using Docker Compose:
```bash
docker compose up mysql -d
```

2. Build and run PetClinic with MySQL profile:
```bash
./mvnw clean package -DskipTests
docker build -t spring-petclinic:latest .

docker run -d -p 8080:8080 \
  --name petclinic \
  --network spring-petclinic_default \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/petclinic \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  spring-petclinic:latest
```

### Using PostgreSQL

1. Start PostgreSQL using Docker Compose:
```bash
docker compose up postgres -d
```

2. Build and run PetClinic with PostgreSQL profile:
```bash
./mvnw clean package -DskipTests
docker build -t spring-petclinic:latest .

docker run -d -p 8080:8080 \
  --name petclinic \
  --network spring-petclinic_default \
  -e SPRING_PROFILES_ACTIVE=postgres \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/petclinic \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  spring-petclinic:latest
```

---

## Docker Compose Full Stack

Create a `docker-compose.full.yml` file:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: mysql
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/petclinic
      SPRING_DATASOURCE_USERNAME: petclinic
      SPRING_DATASOURCE_PASSWORD: petclinic
    depends_on:
      - mysql
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 3s
      start_period: 60s
      retries: 3

  mysql:
    image: mysql:9.2
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_USER: petclinic
      MYSQL_PASSWORD: petclinic
      MYSQL_DATABASE: petclinic
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

Run the full stack:
```bash
./mvnw clean package -DskipTests
docker compose -f docker-compose.full.yml up --build
```

---

## Environment Variables

### Common Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `SPRING_PROFILES_ACTIVE` | Active Spring profile (h2, mysql, postgres) | (none - defaults to h2) |
| `JAVA_OPTS` | Additional JVM options | See Dockerfile |

### Database Configuration (MySQL/PostgreSQL)

| Variable | Description | Example |
|----------|-------------|---------|
| `SPRING_DATASOURCE_URL` | JDBC connection URL | `jdbc:mysql://mysql:3306/petclinic` |
| `SPRING_DATASOURCE_USERNAME` | Database username | `petclinic` |
| `SPRING_DATASOURCE_PASSWORD` | Database password | `petclinic` |

### Memory Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `JAVA_OPTS` | Custom JVM options | Container-optimized settings |

Example custom memory settings:
```bash
docker run -d -p 8080:8080 \
  --name petclinic \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  spring-petclinic:latest
```

---

## Image Information

### Image Details

- **Base Image**: `eclipse-temurin:17-jre-jammy`
- **Final Image Size**: ~330MB
- **Java Version**: 17 (runtime)
- **Build Java Version**: 25 (required for building)
- **User**: Non-root user `spring` (UID varies)
- **Working Directory**: `/app`
- **Exposed Port**: 8080

### Health Check

The image includes a built-in health check that queries the Spring Boot Actuator health endpoint:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
```

---

## Advanced Usage

### Custom Port Mapping

```bash
docker run -d -p 9090:8080 --name petclinic spring-petclinic:latest
# Access at http://localhost:9090
```

### Viewing Actuator Endpoints

```bash
# Health check
curl http://localhost:8080/actuator/health

# Application info
curl http://localhost:8080/actuator/info

# Metrics
curl http://localhost:8080/actuator/metrics

# All available endpoints
curl http://localhost:8080/actuator
```

### Running with Resource Limits

```bash
docker run -d -p 8080:8080 \
  --name petclinic \
  --memory=1g \
  --cpus=1.0 \
  spring-petclinic:latest
```

### Debugging

Run in interactive mode to see logs in real-time:
```bash
docker run -it --rm -p 8080:8080 spring-petclinic:latest
```

View logs from a running container:
```bash
docker logs -f petclinic
```

Execute commands inside the container:
```bash
docker exec -it petclinic /bin/bash
```

---

## Building for Different Architectures

### Multi-platform Build

```bash
# Build for AMD64 and ARM64
docker buildx build --platform linux/amd64,linux/arm64 -t spring-petclinic:latest .
```

---

## Troubleshooting

### Container Won't Start

1. Check logs:
   ```bash
   docker logs petclinic
   ```

2. Verify port is not in use:
   ```bash
   lsof -i :8080
   ```

3. Check if JAR was built:
   ```bash
   ls -lh target/*.jar
   ```

### Database Connection Issues

1. Verify database is running:
   ```bash
   docker ps | grep mysql  # or postgres
   ```

2. Check network connectivity:
   ```bash
   docker network inspect spring-petclinic_default
   ```

3. Verify environment variables:
   ```bash
   docker inspect petclinic | grep -A10 Env
   ```

### Application Not Responding

1. Check health status:
   ```bash
   curl http://localhost:8080/actuator/health
   ```

2. Verify container is running:
   ```bash
   docker ps | grep petclinic
   ```

3. Check resource usage:
   ```bash
   docker stats petclinic
   ```

---

## Production Considerations

### Security

1. **Use specific image tags** instead of `latest`:
   ```bash
   docker build -t spring-petclinic:4.0.0-SNAPSHOT .
   ```

2. **Scan for vulnerabilities**:
   ```bash
   docker scan spring-petclinic:latest
   ```

3. **Use secrets management** for sensitive data:
   ```bash
   # Use Docker secrets (Swarm) or Kubernetes secrets
   # Don't pass passwords via environment variables in production
   ```

4. **Limit Actuator endpoints** in production:
   ```bash
   docker run -d -p 8080:8080 \
     -e MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info \
     spring-petclinic:latest
   ```

### Performance

1. **Set appropriate resource limits**
2. **Use persistent volumes** for database data
3. **Enable JVM container support** (already configured)
4. **Monitor with Actuator metrics**

### Logging

Configure centralized logging:
```bash
docker run -d -p 8080:8080 \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  spring-petclinic:latest
```

---

## CI/CD Integration

### Example GitHub Actions Workflow

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 25
        uses: actions/setup-java@v3
        with:
          java-version: '25'
          distribution: 'temurin'
      
      - name: Build with Maven
        run: ./mvnw clean package -DskipTests
      
      - name: Build Docker image
        run: docker build -t spring-petclinic:${{ github.sha }} .
      
      - name: Test Docker image
        run: |
          docker run -d --name test -p 8080:8080 spring-petclinic:${{ github.sha }}
          sleep 30
          curl -f http://localhost:8080/actuator/health
          docker stop test
```

---

## Additional Resources

- [Spring Boot Docker Documentation](https://spring.io/guides/topical/spring-boot-docker/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Spring PetClinic Documentation](../README.md)
- [Containerization Readiness Report](../CONTAINERIZATION_READINESS_REPORT.md)
