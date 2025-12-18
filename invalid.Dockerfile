# Multi-stage build for Spring Boot Maven application
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy Maven wrapper files for dependency resolution
COPY .mvn/wrapper .mvn/wrapper
COPY mvnw .
COPY pom.xml .

# Download all dependencies (this layer is cached)
RUN ./mvnw dependency:go-offline -B

# Copy application source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests -B

# Production runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring

WORKDIR /app

# Copy built artifact from build stage
COPY --from=build /workspace/app/target/*.jar app.jar

# Set ownership to non-root user
RUN chown -R spring:spring /app

# Run as non-root user
USER spring:spring

# Expose application port
EXPOSE 8080

# Health check for container monitoring
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8080/actuator/health || exit 1

# Application entry point
ENTRYPOINT ["java", "-jar", "app.jar"]
