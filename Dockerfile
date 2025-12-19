# Dockerfile for Spring PetClinic
# This Dockerfile expects the application to be pre-built.
# Build the JAR first: ./mvnw clean package -DskipTests

FROM eclipse-temurin:17-jre-jammy

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy the pre-built JAR file
COPY target/*.jar /app/app.jar

# Change ownership to non-root user
RUN chown spring:spring /app/app.jar

# Switch to non-root user
USER spring:spring

WORKDIR /app

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
