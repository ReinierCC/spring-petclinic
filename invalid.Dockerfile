# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app

# Install tar which is required for Maven
RUN tdnf install -y tar && tdnf clean all

# Copy dependency manifests for layer caching (Maven and Gradle)
COPY mvnw .
COPY gradlew .
COPY .mvn .mvn
COPY gradle gradle
COPY pom.xml .
COPY build.gradle .
COPY settings.gradle .

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy application source
COPY src src

# Build application
RUN ./mvnw package -DskipTests

# Production stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app

# Install curl for healthcheck and ca-certificates for HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy application JAR from build stage
COPY --from=build /workspace/app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown spring:spring app.jar

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Expose port
EXPOSE 8080

# Run as non-root user
USER spring

# Run the application
ENTRYPOINT ["java","-jar","app.jar"]
