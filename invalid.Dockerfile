# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /app

# Install tar for Maven (not pre-installed in azurelinux)
RUN tdnf install -y tar

# Copy Maven wrapper and pom.xml for dependency caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline

# Copy source code
COPY src src

# Build application
RUN ./mvnw package -DskipTests

# Runtime stage with distroless image
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

# Create non-root user
USER 65532:65532

# Copy built artifact
COPY --from=build /app/target/*.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD ["java", "-cp", "app.jar", "org.springframework.boot.loader.JarLauncher", "--server.port=8080"]

# Expose port
EXPOSE 8080

# Run application
CMD ["java", "-jar", "app.jar"]
