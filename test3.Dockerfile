FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /app
COPY . .

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
RUN groupadd -r spring && useradd -r -g spring spring
WORKDIR /app
COPY --from=build /app /app
RUN chown -R spring:spring /app
USER spring:spring
