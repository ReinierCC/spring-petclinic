# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN ./mvnw dependency:go-offline

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Create non-root user
USER nonroot:nonroot

WORKDIR /app

# Copy the built artifact from build stage
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/*.jar app.jar

# Expose the application port
EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
