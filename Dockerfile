# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage Dockerfile for Spring PetClinic
# Build stage
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /workspace/app

# Copy the pre-built JAR file
COPY target/*.jar application.jar

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy JAR from build stage
COPY --from=build /workspace/app/application.jar /app/application.jar

# Set ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring:spring

# Expose application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "/app/application.jar"]


