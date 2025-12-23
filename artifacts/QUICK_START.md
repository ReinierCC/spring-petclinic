# Quick Start Guide - Dockerized Spring PetClinic

## Prerequisites
- Docker installed
- Java 17 (for building the JAR)
- Git

## Build & Run (Simple)

```bash
# 1. Clone the repository (if not already done)
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic

# 2. Build the application
./gradlew build -x test --no-daemon

# 3. Build the Docker image
docker build -t spring-petclinic:1.0 .

# 4. Run the container
docker run -d -p 8080:8080 --name petclinic spring-petclinic:1.0

# 5. Access the application
open http://localhost:8080
# or
curl http://localhost:8080/actuator/health
```

## Stop & Clean Up

```bash
docker stop petclinic
docker rm petclinic
```

## View Logs

```bash
docker logs petclinic
```

## Advanced: With MySQL Database

```bash
# Use the existing docker-compose.yml
docker-compose up -d
```

---

**Image Tag**: `spring-petclinic:1.0`  
**Port**: `8080`  
**Health Check**: `/actuator/health`
