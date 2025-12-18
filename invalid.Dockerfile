# Multi-stage build for Spring PetClinic
# Build stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

# Create non-root user
USER nonroot:nonroot

# Copy the built application from build stage
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/META-INF /app/META-INF
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/classes /app

# Expose port 8080
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD java -cp /app org.springframework.boot.actuator.health.HealthEndpoint || exit 1

# Run the application
ENTRYPOINT ["java", "-cp", "/app:/app/lib/*", "org.springframework.samples.petclinic.PetClinicApplication"]
