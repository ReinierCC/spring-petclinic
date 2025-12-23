# Multi-stage Dockerfile for Spring PetClinic
# Build stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (cached layer if pom.xml hasn't changed)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application (tests are run separately in CI/CD pipeline)
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../spring-petclinic-*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

# Copy the unpacked application from build stage
ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Run as non-root user (distroless nonroot user is 65532)
USER 65532:65532

# Expose default Spring Boot port
EXPOSE 8080

# Run the application with JVM optimizations for containers
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-cp", "/app:/app/lib/*", "org.springframework.samples.petclinic.PetClinicApplication"]
