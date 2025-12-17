# Test Dockerfile with invalid registry
FROM docker.io/node:20-alpine

# Set working directory
WORKDIR /app

# Copy dependency files first for better layer caching
COPY package*.json ./

# Install dependencies (if package.json exists)
RUN if [ -f package.json ]; then npm ci --only=production; fi

# Copy application source code
COPY . .

# Use non-root user for security
USER node

# Document exposed port
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))" || exit 1

# Run the application
CMD ["node", "app.js"]
