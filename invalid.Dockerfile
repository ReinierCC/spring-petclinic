# Multi-stage build for Spring PetClinic
FROM mcr.microsoft.com/openjdk/jdk:17-mariner AS build
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw package -DskipTests

FROM mcr.microsoft.com/openjdk/jdk:17-mariner
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
USER nobody
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
