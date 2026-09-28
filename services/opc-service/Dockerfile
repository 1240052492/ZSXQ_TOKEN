# OPC Service Dockerfile
FROM node:24.18.0-alpine AS base

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY services/opc-service ./services/opc-service
COPY services/lib ./services/lib
COPY vendor/agency-orchestrator ./vendor/agency-orchestrator

# Expose port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --spider -q http://localhost:3002/health || exit 1

# Run as non-root user
USER node

CMD ["node", "services/opc-service/index.js"]
