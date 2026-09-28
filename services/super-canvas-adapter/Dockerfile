# Super Canvas Adapter Dockerfile
FROM node:24.18.0-alpine AS base

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY services/super-canvas-adapter ./services/super-canvas-adapter
COPY services/lib ./services/lib
COPY vendor/TapCanvas ./vendor/TapCanvas

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --spider -q http://localhost:3001/health || exit 1

# Run as non-root user
USER node

CMD ["node", "services/super-canvas-adapter/index.js"]
