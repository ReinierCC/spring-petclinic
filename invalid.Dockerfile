# Multi-stage build for Spring Petclinic
FROM mcr.microsoft.com/openjdk/jdk:25-azurelinux AS build
WORKDIR /workspace/app

# Install tar which is required for Maven but not pre-installed in Azure Linux image
RUN tdnf install -y tar

# Copy Maven wrapper and pom.xml first for better layer caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (this layer will be cached)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests && \
    mkdir -p target/dependency && \
    cd target/dependency && \
    jar -xf ../*.jar

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:25-distroless

# Copy application from build stage
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/META-INF /app/META-INF
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/classes /app

# Expose port for Spring Boot application
EXPOSE 8080

# Run as non-root user
USER nonroot:nonroot

# Run application with optimal JVM settings
ENTRYPOINT ["java","-XX:+UseContainerSupport","-XX:MaxRAMPercentage=75.0","-cp","app:app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]
