# Multi-stage build for Spring PetClinic
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace/app

# Copy dependency files first for better layer caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies - separate layer
RUN ./mvnw dependency:resolve dependency:resolve-plugins

# Copy source code - separate layer
COPY src src

# Build application
RUN ./mvnw package -DskipTests && \
    mkdir -p target/dependency && \
    cd target/dependency && \
    jar -xf ../*.jar

FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app

USER nonroot:nonroot

# Copy dependencies first - cached layer
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/lib /app/lib

# Copy metadata - separate layer
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/META-INF /app/META-INF

# Copy application classes last - only rebuilds when code changes
COPY --from=build --chown=nonroot:nonroot /workspace/app/target/dependency/BOOT-INF/classes /app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 CMD ["java","-version"]

ENTRYPOINT ["java","-cp","/app:/app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]



