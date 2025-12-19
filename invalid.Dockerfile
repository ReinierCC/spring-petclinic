# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot Petclinic
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY .mvn .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Create non-root user
USER nonroot:nonroot

WORKDIR /app

# Copy application from build stage
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/META-INF /app/META-INF
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/classes /app

# Expose application port
EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD ["java", "-cp", "/app:/app/lib/*", "org.springframework.boot.actuate.health.HealthEndpointSupport"]

ENTRYPOINT ["java", "-cp", "/app:/app/lib/*", "org.springframework.samples.PetClinicApplication"]
