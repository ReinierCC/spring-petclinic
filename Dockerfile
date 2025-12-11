# Multi-stage Dockerfile for Spring PetClinic
# Stage 1: Build the application
FROM eclipse-temurin:17-jdk-jammy AS builder

WORKDIR /workspace/app

# Copy all files needed for build
COPY . .

# Build the application (Maven wrapper will download dependencies as needed)
RUN chmod +x mvnw && \
    ./mvnw package -DskipTests -Dmaven.test.skip=true && \
    mkdir -p target/dependency && \
    (cd target/dependency; jar -xf ../*.jar)

# Stage 2: Create the runtime image
FROM eclipse-temurin:17-jre-jammy

# Create a non-root user
RUN groupadd -r spring && useradd -r -g spring spring

WORKDIR /app

# Copy the application from builder stage
ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=builder ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=builder ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=builder ${DEPENDENCY}/BOOT-INF/classes /app

# Set ownership to spring user
RUN chown -R spring:spring /app
USER spring:spring

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-cp", "app:app/lib/*", "org.springframework.samples.petclinic.PetClinicApplication"]
