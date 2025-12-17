# Build stage
FROM maven:3.9-eclipse-temurin-17 as build
WORKDIR /app

# Copy dependency files first for better layer caching
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN ./mvnw dependency:go-offline

# Copy source code and build
COPY src ./src
RUN ./mvnw clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy application jar
COPY --from=build /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

EXPOSE 8080

# Add health check for Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD java -cp app.jar org.springframework.boot.loader.JarLauncher --management.endpoint.health.show-details=always || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
