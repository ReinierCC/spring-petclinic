# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Install tar for Maven builds
RUN apt-get update && apt-get install -y tar curl && rm -rf /var/lib/apt/lists/*

# Copy dependency files first for optimal caching
COPY pom.xml ./pom.xml
COPY mvnw ./mvnw
COPY .mvn ./.mvn

# Download all dependencies (this layer will be cached)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu-jre
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring
RUN chown -R spring:spring /app

# Copy dependencies first (least likely to change, best for caching)
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/BOOT-INF/lib ./lib

# Copy metadata
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/META-INF ./META-INF

# Copy application classes last (most likely to change)
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/BOOT-INF/classes .

# Switch to non-root user
USER spring

EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-cp",".:/app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]
