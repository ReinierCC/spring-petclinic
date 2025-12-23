# Multi-stage Dockerfile for Spring Boot Petclinic
# This Dockerfile assumes the JAR has been built externally (e.g., in CI/CD pipeline)
# Build the JAR first with: ./mvnw clean package -DskipTests

FROM eclipse-temurin:17-jre-jammy

# Install wget for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy the pre-built JAR file
COPY target/spring-petclinic-*.jar app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

USER spring

EXPOSE 8080

# Health check using Spring Boot Actuator endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
