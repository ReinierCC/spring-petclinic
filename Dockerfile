# Spring PetClinic - Production Dockerfile
# Optimized for Spring Boot 4.0.0-M3
# 
# USAGE (Build JAR first, then Docker image):
#   ./mvnw clean package -DskipTests
#   docker build -t spring-petclinic:latest .
#
# This Dockerfile expects the JAR to be pre-built in target/ directory.

# ============================================
# Runtime Stage
# ============================================
FROM eclipse-temurin:17-jre-jammy

# Add metadata
LABEL maintainer="Spring PetClinic Team"
LABEL description="Spring PetClinic - A sample Spring Boot application"
LABEL version="4.0.0-SNAPSHOT"

# Create a non-root user to run the application for security
RUN groupadd -r spring && useradd -r -g spring spring

# Set working directory
WORKDIR /app

# Copy the pre-built JAR file
# Ensure you run './mvnw clean package -DskipTests' before building the Docker image
COPY --chown=spring:spring target/*.jar app.jar

# Switch to non-root user for security
USER spring:spring

# Expose application port
EXPOSE 8080

# Set JVM options for containerized environment
# - Respect container memory limits
# - Optimize for container startup time
# - Enable proper signal handling for graceful shutdown
ENV JAVA_OPTS="-XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -XX:+OptimizeStringConcat \
    -XX:+UseStringDeduplication \
    -Djava.security.egd=file:/dev/./urandom"

# Health check using Spring Boot Actuator health endpoint
# Container orchestrators (Docker, Kubernetes) will use this to determine application health
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the Spring Boot application
# The JAR is executable and contains all dependencies
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
