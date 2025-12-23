# Production Dockerfile for Spring PetClinic
# This Dockerfile assumes the JAR is already built (build/libs/*.jar)
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Install wget for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy the pre-built JAR file
COPY build/libs/*.jar app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application with optimized JVM settings for containers
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "app.jar"]
