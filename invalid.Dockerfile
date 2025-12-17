# Production-ready Dockerfile for Spring Boot Pet Clinic Application
# Using pre-built JAR file to avoid SSL certificate issues in build environment
FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Use non-root user (app user is pre-configured in the base image)
USER app

WORKDIR /app

# Copy the pre-built JAR file
COPY --chown=app:app target/spring-petclinic-4.0.0-SNAPSHOT.jar app.jar

# Expose application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
