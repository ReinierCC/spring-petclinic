# Dockerfile for Spring Boot PetClinic
# Note: Build the JAR first with: ./gradlew clean bootJar --no-daemon
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

# Copy built artifact
COPY build/libs/*.jar app.jar

# Change ownership
RUN chown -R petclinic:petclinic /app

# Switch to non-root user
USER petclinic

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
