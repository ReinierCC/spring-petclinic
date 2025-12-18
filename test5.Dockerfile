FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /workspace/app
RUN tdnf install -y tar && tdnf clean all
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw dependency:go-offline -B
COPY src src
RUN ./mvnw package -DskipTests

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd -r appuser && useradd -r -g appuser appuser
COPY --from=build /workspace/app/target/*.jar app.jar
RUN chown appuser:appuser app.jar
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 CMD curl -f http://localhost:8080/actuator/health || exit 1
EXPOSE 8080
USER appuser
ENTRYPOINT ["java","-jar","app.jar"]
