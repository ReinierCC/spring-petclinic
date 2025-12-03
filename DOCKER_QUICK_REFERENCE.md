# Spring PetClinic - Docker Quick Reference

## 🚀 Quick Start (60 seconds)

```bash
# 1. Build the JAR (requires Java 25)
./mvnw clean package -DskipTests

# 2. Build Docker image
docker build -t spring-petclinic:latest .

# 3. Run
docker run -d -p 8080:8080 --name petclinic spring-petclinic:latest

# 4. Access
open http://localhost:8080

# 5. Check health
curl http://localhost:8080/actuator/health
```

## 📊 Image Info

- **Size:** 330MB
- **Base:** eclipse-temurin:17-jre-jammy
- **Port:** 8080
- **User:** Non-root (spring)
- **Health Check:** ✅ Built-in

## 🗂️ Documentation Files

| File | Purpose |
|------|---------|
| `DOCKER_USAGE.md` | Complete usage guide |
| `CONTAINERIZATION_READINESS_REPORT.md` | 95/100 readiness analysis |
| `DOCKER_IMPLEMENTATION_SUMMARY.md` | Implementation overview |
| `Dockerfile` | Container image definition |
| `.dockerignore` | Build optimization |

## 🔧 Common Commands

```bash
# View logs
docker logs petclinic

# Stop & remove
docker stop petclinic && docker rm petclinic

# Run with MySQL
docker run -d -p 8080:8080 \
  --network spring-petclinic_default \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/petclinic \
  spring-petclinic:latest

# Interactive mode (debugging)
docker run -it --rm -p 8080:8080 spring-petclinic:latest
```

## 📈 Readiness Score: 95/100

✅ Cloud-native design  
✅ Stateless architecture  
✅ Health checks  
✅ Multi-database support  
✅ Externalized config  
✅ Security best practices  

## 💡 Key Features

- **Multi-stage build ready** (can be extended)
- **Non-root execution** (security)
- **Health checks** (orchestration-ready)
- **Optimized JVM** (container-aware)
- **Documentation** (comprehensive)

---

For detailed information, see `DOCKER_USAGE.md`
