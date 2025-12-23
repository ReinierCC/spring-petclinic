# Build stage  
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy all build configuration files for optimal layer caching
COPY pom.xml build.gradle settings.gradle ./
COPY .mvn .mvn
COPY gradle gradle
COPY mvnw gradlew ./

# Download dependencies (cached layer if build config doesn't change)
RUN ./mvnw dependency:go-offline -B

# Copy source code (only rebuilds if source changes)
COPY src src

# Build the application
RUN ./mvnw package -DskipTests

# Runtime stage using slim image for health check support
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app

# Create and use non-root user
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

# Copy the built artifact
COPY --from=build /workspace/app/target/*.jar app.jar

EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java","-jar","app.jar"]
