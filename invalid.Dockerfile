# syntax=docker/dockerfile:1

# Build arguments
ARG JAVA_VERSION=17
ARG MARINER_VERSION=mariner

# Multi-stage build for Spring PetClinic
FROM mcr.microsoft.com/openjdk/jdk:${JAVA_VERSION}-${MARINER_VERSION} AS build

# Add metadata labels
LABEL maintainer="Spring PetClinic Team" \
      org.opencontainers.image.title="Spring PetClinic Build" \
      org.opencontainers.image.description="Build stage for Spring PetClinic" \
      org.opencontainers.image.version="4.0.0"

WORKDIR /workspace/app

# Layer 1: Copy Maven wrapper (rarely changes)
COPY mvnw ./
COPY .mvn ./.mvn

# Layer 2: Copy dependency management files (changes less frequently)
COPY pom.xml ./

# Layer 3: Resolve and download dependencies (cached until pom.xml changes)
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline -B

# Layer 4: Copy application source (changes most frequently)
COPY src ./src

# Layer 5: Build application with layer extraction
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw package -DskipTests && \
    mkdir -p target/dependency && \
    cd target/dependency && \
    jar -xf ../*.jar

# Runtime stage with minimal footprint
FROM mcr.microsoft.com/openjdk/jdk:${JAVA_VERSION}-${MARINER_VERSION} AS runtime

# Add OCI metadata labels
LABEL maintainer="Spring PetClinic Team" \
      org.opencontainers.image.title="Spring PetClinic" \
      org.opencontainers.image.description="Spring PetClinic Sample Application" \
      org.opencontainers.image.version="4.0.0" \
      org.opencontainers.image.vendor="Spring" \
      org.opencontainers.image.licenses="Apache-2.0"

# System setup: install dependencies and create non-root user
RUN tdnf install -y curl && \
    tdnf clean all && \
    rm -rf /var/cache/tdnf /tmp/* /var/tmp/* && \
    groupadd -r -g 1000 spring && \
    useradd -r -u 1000 -g spring -m -d /home/spring spring

WORKDIR /app

# Copy Spring Boot application layers from build stage
ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=build --chown=spring:spring ${DEPENDENCY}/BOOT-INF/lib ./lib
COPY --from=build --chown=spring:spring ${DEPENDENCY}/META-INF ./META-INF
COPY --from=build --chown=spring:spring ${DEPENDENCY}/BOOT-INF/classes ./

# JVM optimization environment variables
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

# Run as non-root user
USER spring:spring

# Document exposed port
EXPOSE 8080

# Health check configuration
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Application entrypoint
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -cp ./:./lib/* org.springframework.samples.petclinic.PetClinicApplication"]
