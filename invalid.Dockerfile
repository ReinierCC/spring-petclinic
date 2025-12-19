# CREATED BY CA - VERIFIED THROUGH REGO
# Multi-stage build for Spring Boot application
FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app

# Install tar which is required for Maven wrapper
RUN tdnf install -y tar

# Copy Maven wrapper and pom.xml for dependency caching
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (this layer will be cached)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM mcr.microsoft.com/openjdk/jdk:17-distroless
ARG DEPENDENCY=/workspace/app/target/dependency
VOLUME /tmp

# Copy application files
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Run as non-root user (distroless already runs as non-root)
ENTRYPOINT ["java","-cp","app:app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]

