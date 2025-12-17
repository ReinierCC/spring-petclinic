# Multi-stage Dockerfile for Spring PetClinic Application

# Stage 1: Build stage
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy Maven wrapper and pom.xml first for better caching
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached if pom.xml hasn't changed)
RUN ./mvnw dependency:go-offline

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw package -DskipTests

# Stage 2: Runtime stage
FROM eclipse-temurin:17-jre

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring

# Copy the built artifact from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Expose the application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application with JVM optimizations
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
