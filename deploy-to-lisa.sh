#!/bin/bash
set -e

# Lisa服务器部署脚本
# 用途: 将Docker镜像和配置部署到Lisa服务器

LISA_HOST="lisa"
LISA_USER="root"
DEPLOY_DIR="/opt/zsxq_token"
VERSION="v0.1.0"

echo "=== ZSXQ_TOKEN Lisa Deployment ==="
echo "Target: ${LISA_USER}@${LISA_HOST}:${DEPLOY_DIR}"
echo "Version: ${VERSION}"
echo ""

# 1. 创建部署目录
echo "[1/6] Creating deployment directory..."
ssh ${LISA_USER}@${LISA_HOST} "mkdir -p ${DEPLOY_DIR}/db/init"

# 2. 传输配置文件
echo "[2/6] Uploading configuration files..."
scp docker-compose.lisa.yml ${LISA_USER}@${LISA_HOST}:${DEPLOY_DIR}/docker-compose.yml
scp .env.local ${LISA_USER}@${LISA_HOST}:${DEPLOY_DIR}/.env
scp db/init/*.sql ${LISA_USER}@${LISA_HOST}:${DEPLOY_DIR}/db/init/

# 3. 登录GHCR并拉取Docker镜像
echo "[3/6] Pulling Docker images on Lisa..."
echo "Note: Using local GitHub token for authentication"
ssh ${LISA_USER}@${LISA_HOST} << ENDSSH
cd /opt/zsxq_token
# Login to GHCR
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u 1240052492 --password-stdin
# Pull images
docker pull ghcr.io/1240052492/zsxq_token/new-api:v0.1.0
docker pull ghcr.io/1240052492/zsxq_token/platform-gateway:v0.1.0
docker pull ghcr.io/1240052492/zsxq_token/super-canvas-adapter:v0.1.0
docker pull ghcr.io/1240052492/zsxq_token/opc-service:v0.1.0
docker pull postgres:16-alpine
docker pull redis:7-alpine
ENDSSH

# 4. 停止旧服务
echo "[4/6] Stopping existing services..."
ssh ${LISA_USER}@${LISA_HOST} "cd ${DEPLOY_DIR} && docker compose down || true"

# 5. 启动新服务
echo "[5/6] Starting services..."
ssh ${LISA_USER}@${LISA_HOST} "cd ${DEPLOY_DIR} && docker compose up -d"

# 6. 健康检查
echo "[6/6] Running health checks..."
sleep 10
ssh ${LISA_USER}@${LISA_HOST} << 'ENDSSH'
cd /opt/zsxq_token
echo "Checking service health..."
docker compose ps
echo ""
echo "Testing endpoints:"
curl -f http://localhost:8080/health && echo "✓ new-api healthy" || echo "✗ new-api failed"
curl -f http://localhost:3000/health && echo "✓ platform-gateway healthy" || echo "✗ platform-gateway failed"
curl -f http://localhost:3001/health && echo "✓ super-canvas-adapter healthy" || echo "✗ super-canvas-adapter failed"
curl -f http://localhost:3002/health && echo "✓ opc-service healthy" || echo "✗ opc-service failed"
ENDSSH

echo ""
echo "=== Deployment Complete ==="
echo "Services are running at:"
echo "  - Platform Gateway: http://lisa:3000"
echo "  - Super Canvas: http://lisa:3001"
echo "  - OPC Service: http://lisa:3002"
echo "  - New API: http://lisa:8080"
echo ""
echo "View logs: ssh ${LISA_USER}@${LISA_HOST} 'cd ${DEPLOY_DIR} && docker-compose logs -f'"
