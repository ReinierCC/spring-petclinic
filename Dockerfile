# CREATED BY CA - VERIFIED THROUGH REGO
# Dockerfile for Spring Boot Petclinic application

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy the built JAR file
COPY build/libs/spring-petclinic-4.0.0-SNAPSHOT.jar /app/app.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring:spring

# Expose application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
