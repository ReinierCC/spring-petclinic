# Multi-stage build for Spring Boot Petclinic application

# Build stage
FROM mcr.microsoft.com/openjdk/jdk:17-mariner AS build
WORKDIR /workspace/app

# Install tar for Maven (required for Azure Linux)
RUN tdnf install -y tar && tdnf clean all

# Copy only dependency-related files first
COPY pom.xml ./
COPY mvnw ./
COPY .mvn ./.mvn

# Download dependencies (this layer is cached unless pom.xml changes)
RUN chmod +x ./mvnw && ./mvnw dependency:go-offline -B

# Now copy source code (separate layer that only invalidates when code changes)
COPY src ./src

# Build application
RUN ./mvnw package -DskipTests -B

# Extract Spring Boot layers for optimized runtime
RUN mkdir -p target/extracted && java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# Runtime stage with minimal distroless image
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

# Run as non-root user for security
USER 65532:65532

# Copy extracted layers in order of change frequency for optimal layer caching
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/dependencies/ ./
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/spring-boot-loader/ ./
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/snapshot-dependencies/ ./
COPY --from=build --chown=65532:65532 /workspace/app/target/extracted/application/ ./

# Expose application port
EXPOSE 8080

# Configure health check for container orchestration
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 CMD ["/usr/bin/java", "org.springframework.boot.loader.launch.JarLauncher", "--health"]

# Run application using layered JAR structure
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
