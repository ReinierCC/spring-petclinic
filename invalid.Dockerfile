# Dockerfile for Spring PetClinic
# Note: Build the JAR locally first with: ./mvnw package -DskipTests
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy the pre-built JAR file
COPY target/spring-petclinic-4.0.0-SNAPSHOT.jar app.jar

# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring && \
    chown spring:spring app.jar

USER spring:spring

# Expose Spring Boot default port
EXPOSE 8080

# Health check using Spring Boot Actuator (requires curl to be added if needed)
# Note: Removed HEALTHCHECK as it requires curl which increases image size

# Run the application with optimized JVM settings
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
