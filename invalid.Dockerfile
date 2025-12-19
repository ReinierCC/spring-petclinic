# Multi-stage build for Spring PetClinic
# Stage 1: Build stage - uses pre-built JAR or builds from source
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copy all source files and pre-built artifacts
COPY . .

# Use existing JAR if available, otherwise build from source
RUN if [ -f target/*.jar ]; then \
      echo "Using pre-built JAR"; \
      cp target/*.jar app.jar; \
    else \
      echo "Building from source"; \
      ./mvnw package -DskipTests -B && \
      cp target/*.jar app.jar; \
    fi

# Stage 2: Runtime image
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Create a non-root user for security best practices
RUN addgroup -S spring && adduser -S spring -G spring

# Copy the JAR from the builder stage
COPY --from=builder /app/app.jar app.jar

# Change ownership to the non-root user
RUN chown -R spring:spring /app

# Switch to non-root user (security best practice)
USER spring:spring

# Expose the application port
EXPOSE 8080

# Health check endpoint (Spring Boot Actuator)
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the Spring Boot application
ENTRYPOINT ["java", "-jar", "app.jar"]
