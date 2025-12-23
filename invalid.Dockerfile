# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot Petclinic
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN chmod +x ./mvnw

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build application
RUN ./mvnw package -DskipTests

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Use numeric UID for distroless (65532 is the standard nonroot user)
USER 65532:65532

WORKDIR /app

# Copy the JAR file directly
COPY --from=build --chown=65532:65532 /workspace/app/target/spring-petclinic-*.jar /app/app.jar

# Expose application port
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
