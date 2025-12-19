# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot Petclinic
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better layer caching
COPY .mvn .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build application
RUN ./mvnw package -DskipTests && \
    mkdir -p target/dependency && \
    (cd target/dependency; jar -xf ../spring-petclinic-*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless

# Use numeric UID for distroless (65532 is the standard nonroot user)
USER 65532:65532

WORKDIR /app

# Copy Spring Boot loader classes
COPY --from=build --chown=65532:65532 /workspace/app/target/dependency/org /app/org

# Copy application from build stage
COPY --from=build --chown=65532:65532 /workspace/app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build --chown=65532:65532 /workspace/app/target/dependency/META-INF /app/META-INF
COPY --from=build --chown=65532:65532 /workspace/app/target/dependency/BOOT-INF/classes /app

# Expose application port
EXPOSE 8080

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
