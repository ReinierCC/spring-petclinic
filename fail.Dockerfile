# Test: Should fail
FROM docker.io/library/node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "index.js"]
