FROM mcr.microsoft.com/openjdk/jdk:17-azurelinux AS build
LABEL org.opencontainers.image.title="Spring PetClinic"
WORKDIR /app
COPY . .
RUN ./mvnw package -DskipTests

FROM mcr.microsoft.com/openjdk/jdk:17-distroless
LABEL org.opencontainers.image.title="Spring PetClinic"
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
USER nonroot
ENTRYPOINT ["java", "-jar", "app.jar"]
