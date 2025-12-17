# Test Dockerfile with invalid registry
FROM docker.io/node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "app.js"]
