# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Install tar for Maven builds
RUN apt-get update && apt-get install -y tar curl && rm -rf /var/lib/apt/lists/*

# Copy only POM file first for dependency caching
COPY pom.xml .

# Copy Maven wrapper
COPY mvnw .
COPY .mvn .mvn

# Download dependencies in a separate layer (cached)
RUN ./mvnw dependency:go-offline -B

# Copy source code (changes frequently)
COPY src src

# Build the application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu-jre
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring
RUN chown -R spring:spring /app

# Copy application files in optimal order for layer caching
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/BOOT-INF/lib ./lib
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/META-INF ./META-INF
COPY --from=build --chown=spring:spring /workspace/app/target/dependency/BOOT-INF/classes .

# Switch to non-root user
USER spring

EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-cp",".:/app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]
