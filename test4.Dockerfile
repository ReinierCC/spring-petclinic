FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /app
COPY . .

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN groupadd -r spring && useradd -r -g spring spring
WORKDIR /app
COPY --from=build /app /app
RUN chown -R spring:spring /app
USER spring:spring
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8080/actuator/health || exit 1
