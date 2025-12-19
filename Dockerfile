# CREATED BY CA - VERIFIED THROUGH REGO
# Dockerfile for Spring Boot PetClinic Application

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

# Copy the pre-built JAR file
COPY target/spring-petclinic-*.jar app.jar

# Change ownership to non-root user
RUN chown -R petclinic:petclinic /app

# Switch to non-root user
USER petclinic

# Expose port 8080
EXPOSE 8080

# Set JVM options for containerized environment
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
