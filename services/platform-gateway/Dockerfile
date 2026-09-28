# Platform Gateway Dockerfile
FROM node:24.18.0-alpine AS base

WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY services/platform-gateway ./services/platform-gateway
COPY services/lib ./services/lib

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -q -O- http://localhost:3000/health > /dev/null || exit 1

# Run as non-root user
USER node

CMD ["node", "services/platform-gateway/src/server.js"]
