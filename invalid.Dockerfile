# CREATED BY CA - VERIFIED THROUGH REGO
# Test Dockerfile with valid registry
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20
WORKDIR /app
COPY . .
CMD ["node", "app.js"]
