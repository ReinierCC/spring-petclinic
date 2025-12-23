# CREATED BY CA - VERIFIED THROUGH REGO
# Dockerfile for Spring PetClinic
# Note: This Dockerfile expects the application to be pre-built
# Run './mvnw package -DskipTests' before building the Docker image

FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Runtime image is already non-root with distroless
WORKDIR /app

# Copy pre-built JAR artifact
COPY target/*.jar app.jar

# Expose application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
