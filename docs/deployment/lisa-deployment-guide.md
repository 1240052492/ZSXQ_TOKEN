# Lisa Server Deployment Guide

## Prerequisites

1. **Docker and Docker Compose installed**
   ```bash
   docker --version  # Should be 20.10+
   docker compose version  # Should be v2.0+
   ```

2. **GitHub Container Registry authentication**
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

3. **Database initialized**
   ```bash
   bash scripts/init-postgres-lisa.sh
   ```

## Deployment Steps

### 1. Download deployment package

```bash
# Create deployment directory
mkdir -p /opt/zsxq_token
cd /opt/zsxq_token

# Download latest release
LATEST_TAG=$(curl -s https://api.github.com/repos/your-org/zsxq-token/releases/latest | grep tag_name | cut -d '"' -f 4)
wget https://github.com/your-org/zsxq-token/releases/download/${LATEST_TAG}/deployment-${LATEST_TAG}.tar.gz

# Extract
tar -xzf deployment-${LATEST_TAG}.tar.gz
```

### 2. Configure environment

```bash
# Copy and edit production environment
cp .env.example .env

# Edit with actual credentials
vim .env
```

**Required changes in `.env`:**
- `GITHUB_REPOSITORY=your-org/zsxq-token`
- `IMAGE_TAG=latest` (or specific version tag)
- `POSTGRES_ROOT_PASSWORD=<from init script>`
- `SERVICE_TOKEN_SECRET=<from init script>`
- `JWT_SECRET=<from init script>`
- `SESSION_SECRET=<from init script>`
- `OPC_SSO_INTERNAL_TOKEN=<from init script>`
- `NEW_API_DB_PASSWORD=<from init script>`
- `OPC_DB_PASSWORD=<from init script>`
- `CANVAS_DB_PASSWORD=<from init script>`

### 3. Initialize databases (first time only)

```bash
# Run database initialization script
bash scripts/init-postgres-lisa.sh

# Save the output passwords to .env
```

### 4. Pull Docker images

```bash
# Pull all service images
docker compose pull
```

### 5. Start services

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps
```

### 6. Verify deployment

```bash
# Run health check
bash scripts/health-check.sh

# Check service logs
docker compose logs -f --tail=100
```

## Service Endpoints

- **Platform Gateway**: http://localhost:3000
- **Super Canvas Adapter**: http://localhost:3001
- **OPC Service**: http://localhost:3002
- **New API**: http://localhost:8080

## Health Check URLs

- Platform Gateway: http://localhost:3000/health
- Super Canvas Adapter: http://localhost:3001/health
- OPC Service: http://localhost:3002/health
- New API: http://localhost:8080/health

## Upgrade Process

```bash
cd /opt/zsxq_token

# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Verify health
bash scripts/health-check.sh
```

## Rollback

```bash
# Specify previous version tag
export IMAGE_TAG=v1.0.0

# Recreate with old images
docker compose up -d
```

## Troubleshooting

### Service won't start
```bash
# Check logs
docker compose logs service-name

# Check environment
docker compose config

# Restart specific service
docker compose restart service-name
```

### Database connection issues
```bash
# Test database connectivity
docker compose exec postgres psql -U postgres -c "\l"

# Check database passwords in .env match init script output
```

### Port conflicts
```bash
# Check what's using the port
sudo lsof -i :3000
sudo lsof -i :3001
sudo lsof -i :3002
sudo lsof -i :8080

# Change ports in .env if needed
```

## Monitoring

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f platform-gateway

# Check resource usage
docker stats

# Check container health
docker compose ps
```

## Backup

```bash
# Backup databases
docker compose exec postgres pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v zsxq-postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-data-$(date +%Y%m%d).tar.gz -C /data .
```

## Security

- All secrets should be stored in `.env` file with 600 permissions
- Use strong random passwords (40+ characters)
- Rotate `SERVICE_TOKEN_SECRET` every 90 days
- Enable firewall rules to restrict port access
- Use HTTPS in production (add nginx/traefik reverse proxy)

## Production Checklist

- [ ] Database initialized with secure passwords
- [ ] All `.env` secrets configured
- [ ] Docker images pulled successfully
- [ ] All services started without errors
- [ ] Health checks passing
- [ ] Service logs show no errors
- [ ] Firewall rules configured
- [ ] Backup scheduled
- [ ] Monitoring configured
- [ ] SSL certificates installed (if using HTTPS)
