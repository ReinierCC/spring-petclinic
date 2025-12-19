# CREATED BY CA - VERIFIED THROUGH REGO
# Dockerfile for Spring PetClinic
# Runtime-only image with pre-built JAR

FROM eclipse-temurin:17-jre-jammy

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring

WORKDIR /app

# Copy the pre-built JAR
COPY target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
