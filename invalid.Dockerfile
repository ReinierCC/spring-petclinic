# syntax=docker/dockerfile:1

# Build arguments
ARG JAVA_VERSION=17
ARG MARINER_VERSION=mariner

# Multi-stage build for Spring PetClinic
FROM mcr.microsoft.com/openjdk/jdk:${JAVA_VERSION}-${MARINER_VERSION} AS build

# Add metadata labels
LABEL maintainer="Spring PetClinic Team" \
      org.opencontainers.image.title="Spring PetClinic" \
      org.opencontainers.image.description="Spring PetClinic Sample Application" \
      org.opencontainers.image.version="4.0.0"

WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (separate layer for caching)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency
RUN cd target/dependency && jar -xf ../*.jar

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:${JAVA_VERSION}-${MARINER_VERSION}

# Add metadata labels
LABEL maintainer="Spring PetClinic Team" \
      org.opencontainers.image.title="Spring PetClinic" \
      org.opencontainers.image.description="Spring PetClinic Sample Application" \
      org.opencontainers.image.version="4.0.0"

# Install curl for health check
RUN tdnf install -y curl
RUN tdnf clean all
RUN rm -rf /var/cache/tdnf

# Create non-root user with specific UID/GID
RUN groupadd -r -g 1000 spring
RUN useradd -r -u 1000 -g spring spring

WORKDIR /app

# Copy application layers from build stage with correct ownership
ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=build --chown=spring:spring ${DEPENDENCY}/BOOT-INF/lib ./lib
COPY --from=build --chown=spring:spring ${DEPENDENCY}/META-INF ./META-INF
COPY --from=build --chown=spring:spring ${DEPENDENCY}/BOOT-INF/classes ./

# Environment variables for JVM tuning
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Switch to non-root user
USER spring:spring

# Expose application port
EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 CMD curl -f http://localhost:8080/actuator/health || exit 1

# Set entrypoint
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -cp ./:./lib/* org.springframework.samples.petclinic.PetClinicApplication"]
