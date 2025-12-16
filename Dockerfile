# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot PetClinic Application

# Stage 1: Build stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS builder

WORKDIR /app

# Copy Maven wrapper and pom.xml first for better caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests

# Stage 2: Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu

WORKDIR /app

# Create non-root user for security
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

# Copy the built artifact from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R petclinic:petclinic /app

# Switch to non-root user
USER petclinic

# Expose port 8080
EXPOSE 8080

# Set JVM options for containerized environment
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
