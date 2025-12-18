# Test Dockerfile with valid MCR registry
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:20

# Create non-root user
RUN tdnf install -y shadow-utils && \
    useradd -m -u 1001 appuser && \
    tdnf clean all

WORKDIR /app

# Copy dependency files first for better caching
COPY package*.json ./

# Install dependencies (if package.json exists)
RUN if [ -f package.json ]; then npm ci --only=production; fi

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose application port (common Node.js port)
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "process.exit(0)" || exit 1

CMD ["node", "app.js"]
