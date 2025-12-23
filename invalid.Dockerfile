# Multi-stage build for production
# Build stage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20 AS builder

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install all dependencies (including devDependencies for build)
RUN npm ci

# Copy application code
COPY . .

# Production stage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20 AS production

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy package files
COPY --chown=appuser:appuser package*.json ./

# Install only production dependencies
RUN npm ci --only=production

# Copy built application from builder stage
COPY --from=builder --chown=appuser:appuser /app/app.js ./

# Switch to non-root user
USER appuser

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Expose port
EXPOSE 3000

CMD ["node", "app.js"]
