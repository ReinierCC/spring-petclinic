# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:25-azurelinux AS build
WORKDIR /workspace/app

# Install tar (required for Maven on Azure Linux)
RUN tdnf install -y tar && tdnf clean all

# LAYER CACHING OPTIMIZATION: Copy dependency files before source code
# Step 1: Copy dependency declaration files only
COPY pom.xml .
COPY build.gradle .
COPY settings.gradle .

# Step 2: Copy build tool wrappers
COPY mvnw .
COPY gradlew .
COPY .mvn .mvn
COPY gradle gradle

# Step 3: Download dependencies (cached when source changes)
RUN ./mvnw dependency:go-offline -B || true

# Step 4: Copy source code AFTER dependencies (optimal caching)
COPY src src

# Step 5: Build the application
RUN ./mvnw package -DskipTests

# Step 6: Extract Spring Boot layers for optimal runtime caching
RUN mkdir -p target/extracted && java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# Runtime stage with distroless image
FROM mcr.microsoft.com/openjdk/jdk:25-distroless
WORKDIR /app

# Copy Spring Boot layers in optimal order for caching
COPY --from=build /workspace/app/target/extracted/dependencies/ ./
COPY --from=build /workspace/app/target/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/app/target/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/app/target/extracted/application/ ./

# Distroless images run as non-root by default (user 65532:65532)
USER 65532:65532

# Expose application port
EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application using Spring Boot's JarLauncher
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
