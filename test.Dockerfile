FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
WORKDIR /app
COPY . .
RUN ./mvnw package -DskipTests

FROM mcr.microsoft.com/openjdk/jdk:17-distroless
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
USER nonroot
ENTRYPOINT ["java", "-jar", "app.jar"]
