FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app
COPY . .
CMD ["java", "-version"]
