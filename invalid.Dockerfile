# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build

ARG BUILD_VERSION=4.0.0-SNAPSHOT

WORKDIR /app

# Copy Maven wrapper first
COPY .mvn/ .mvn/
COPY mvnw ./

# Copy dependency descriptor
COPY pom.xml ./

# Download all dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy application source
COPY src/ src/

# Build application
RUN ./mvnw package -DskipTests

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu

ARG BUILD_VERSION=4.0.0-SNAPSHOT

LABEL maintainer="spring-petclinic" \
      version="${BUILD_VERSION}" \
      description="Spring PetClinic Sample Application"

WORKDIR /app

# Install curl and create non-root user
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl=7.* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r appuser && \
    useradd -r -g appuser appuser

# Copy jar with ownership
COPY --from=build --chown=appuser:appuser /app/target/*.jar app.jar

# Run as non-root
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
