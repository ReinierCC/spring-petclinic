# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot application
# Build stage
FROM mcr.microsoft.com/openjdk/jdk:25-azurelinux AS builder
WORKDIR /workspace/app

# Install tar (required for Maven on Azure Linux)
RUN tdnf install -y tar && tdnf clean all

# Layer 1: Copy only dependency files
COPY pom.xml pom.xml

# Layer 2: Copy Maven wrapper
COPY mvnw mvnw
COPY .mvn .mvn

# Layer 3: Download all dependencies (will be cached)
RUN ./mvnw dependency:go-offline -B

# Layer 4: Now copy source code
COPY src src

# Layer 5: Build application
RUN ./mvnw package -DskipTests

# Layer 6: Extract JAR layers
RUN java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# Production stage
FROM mcr.microsoft.com/openjdk/jdk:25-distroless
WORKDIR /app

# Copy extracted layers for optimized caching
COPY --from=builder /workspace/app/target/extracted/dependencies/ ./
COPY --from=builder /workspace/app/target/extracted/spring-boot-loader/ ./
COPY --from=builder /workspace/app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder /workspace/app/target/extracted/application/ ./

# Run as non-root user
USER 65532:65532

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
