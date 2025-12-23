# Test Dockerfile with MCR registry - Multi-stage build
# Build stage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20 AS builder

WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies (if package.json exists)
RUN npm install --production 2>/dev/null || true

# Copy application code
COPY . .

# Production stage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy from build stage
COPY --from=builder /app /app

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Document exposed port
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "app.js"]
