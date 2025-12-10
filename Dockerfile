# Multi-stage build for Spring Boot application

# Build stage
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /workspace/app

# Copy Maven wrapper and pom.xml first for better caching
COPY .mvn .mvn
COPY mvnw .
COPY pom.xml .

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B || true

# Copy source code
COPY src src

# Build the application
RUN ./mvnw package -DskipTests -B

# Extract layers
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
VOLUME /tmp

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

EXPOSE 8080

ENTRYPOINT ["java","-cp","app:app/lib/*","org.springframework.samples.petclinic.PetClinicApplication"]
