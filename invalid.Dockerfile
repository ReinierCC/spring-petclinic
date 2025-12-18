# Multi-stage build for Spring Boot Petclinic application
# Build stage
FROM mcr.microsoft.com/openjdk/jdk:17-mariner AS build
WORKDIR /workspace/app

# Install tar for Maven (required for Azure Linux)
RUN tdnf install -y tar && tdnf clean all

# Layer 1: Copy Maven wrapper files (rarely changes)
COPY mvnw .
COPY .mvn .mvn

# Layer 2: Copy dependency definition file (changes less frequently than source)
COPY pom.xml .

# Layer 3: Download dependencies (cached unless pom.xml changes)
RUN chmod +x ./mvnw && ./mvnw dependency:go-offline -B

# Layer 4: Copy source code (changes frequently)
COPY src src

# Layer 5: Build the application
RUN ./mvnw package -DskipTests -B

# Layer 6: Extract Spring Boot layers for optimal runtime layer caching
RUN mkdir -p target/extracted && \
    java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# Runtime stage with distroless for minimal attack surface
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

# Run as non-root user (distroless nonroot user UID 65532)
USER 65532:65532

# Copy Spring Boot layers separately for better layer caching at runtime
# Dependencies layer (rarely changes)
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/dependencies/ ./
# Spring Boot loader (rarely changes)
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/spring-boot-loader/ ./
# Snapshot dependencies (changes occasionally)
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/snapshot-dependencies/ ./
# Application code (changes frequently)
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/application/ ./

# Expose application port
EXPOSE 8080

# Health check using Java (distroless has no shell)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD ["/usr/bin/java", "org.springframework.boot.loader.launch.JarLauncher", "--health"]

# Run the application using Spring Boot's layered structure
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
