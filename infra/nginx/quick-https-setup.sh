#!/usr/bin/env bash
set -euo pipefail

# Quick HTTPS deployment script for local development
# Uses self-signed certificates and /etc/hosts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════"
echo "  Quick HTTPS Setup (Local Development)"
echo "════════════════════════════════════════════════════════"
echo ""

# Default domains for local development
CANVAS_DOMAIN="canvas.local.zsxq.com"
TOKEN_DOMAIN="token.local.zsxq.com"
API_DOMAIN="api.local.zsxq.com"

echo "This script will:"
echo "  1. Generate self-signed certificates"
echo "  2. Update nginx configurations with local domains"
echo "  3. Create /etc/hosts entries (requires sudo)"
echo "  4. Start nginx with HTTPS"
echo ""

read -p "Continue? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create SSL directory structure
echo ""
echo "Creating SSL directories..."
mkdir -p "$SCRIPT_DIR/ssl/selfsigned"
mkdir -p "$SCRIPT_DIR/ssl/www"
mkdir -p "$SCRIPT_DIR/logs"

# Generate self-signed certificates
echo ""
echo "Generating self-signed certificates..."

for domain in "$CANVAS_DOMAIN" "$TOKEN_DOMAIN" "$API_DOMAIN"; do
    cert_dir="$SCRIPT_DIR/ssl/selfsigned/$domain"
    mkdir -p "$cert_dir"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/privkey.pem" \
        -out "$cert_dir/fullchain.pem" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=ZSXQ/OU=Development/CN=$domain" \
        2>/dev/null

    if [ -f "$cert_dir/fullchain.pem" ]; then
        echo "✅ Certificate created for $domain"
    else
        echo "❌ Failed to create certificate for $domain"
        exit 1
    fi
done

# Update nginx configurations with local domains
echo ""
echo "Updating nginx configurations..."

# Update canvas.conf
sed -i "s/canvas\.yourdomain\.com/$CANVAS_DOMAIN/g" "$SCRIPT_DIR/conf.d/canvas.conf"
sed -i "s|/certbot/|/selfsigned/$CANVAS_DOMAIN/|g" "$SCRIPT_DIR/conf.d/canvas.conf"

# Update token.conf
sed -i "s/token\.yourdomain\.com/$TOKEN_DOMAIN/g" "$SCRIPT_DIR/conf.d/token.conf"
sed -i "s|/certbot/|/selfsigned/$TOKEN_DOMAIN/|g" "$SCRIPT_DIR/conf.d/token.conf"

# Update api.conf
sed -i "s/api\.yourdomain\.com/$API_DOMAIN/g" "$SCRIPT_DIR/conf.d/api.conf"
sed -i "s|/certbot/|/selfsigned/$API_DOMAIN/|g" "$SCRIPT_DIR/conf.d/api.conf"
sed -i "s|https://canvas\.yourdomain\.com|https://$CANVAS_DOMAIN|g" "$SCRIPT_DIR/conf.d/api.conf"

echo "✅ Nginx configurations updated"

# Update /etc/hosts
echo ""
echo "Updating /etc/hosts (requires sudo)..."
echo ""

HOSTS_CONTENT="
# ZSXQ_TOKEN local development domains
127.0.0.1 $CANVAS_DOMAIN
127.0.0.1 $TOKEN_DOMAIN
127.0.0.1 $API_DOMAIN
"

if grep -q "ZSXQ_TOKEN local development" /etc/hosts 2>/dev/null; then
    echo "⚠️  /etc/hosts already contains ZSXQ_TOKEN entries"
else
    echo "$HOSTS_CONTENT" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ /etc/hosts updated"
fi

# Check if services are running
echo ""
echo "Checking backend services..."

check_service() {
    local name=$1
    local port=$2
    if nc -z localhost "$port" 2>/dev/null || netstat -an | grep -q ":$port.*LISTEN" 2>/dev/null; then
        echo "✅ $name is running (port $port)"
        return 0
    else
        echo "⚠️  $name is not running (port $port)"
        return 1
    fi
}

check_service "PostgreSQL" 55432
check_service "Web UI" 5175 || echo "   Start with: cd vendor/TapCanvas && pnpm dev:web"
check_service "New API" 4455 || echo "   Start with: cd vendor/TapCanvas && docker compose up -d new-api"
check_service "Hono API" 8788 || echo "   Start with: cd vendor/TapCanvas/apps/hono-api && pnpm dev"

# Start nginx
echo ""
echo "Starting nginx with HTTPS..."
cd "$SCRIPT_DIR"

docker compose down 2>/dev/null || true
docker compose up -d

sleep 3

if docker ps | grep -q zsxq-nginx; then
    echo "✅ Nginx started successfully"
else
    echo "❌ Failed to start nginx"
    docker compose logs
    exit 1
fi

# Test endpoints
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ HTTPS Setup Complete"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Access your services via HTTPS:"
echo ""
echo "  🌐 Canvas UI:    https://$CANVAS_DOMAIN"
echo "  🔐 Token API:    https://$TOKEN_DOMAIN"
echo "  🔌 Hono API:     https://$API_DOMAIN"
echo ""
echo "Dashboard:"
echo "  📊 New API:      https://$TOKEN_DOMAIN/dashboard"
echo ""
echo "Health checks:"
echo "  curl -k https://$CANVAS_DOMAIN/health"
echo "  curl -k https://$TOKEN_DOMAIN/health"
echo "  curl -k https://$API_DOMAIN/health"
echo ""
echo "⚠️  Note: Self-signed certificates will show browser warnings"
echo "   Click 'Advanced' → 'Proceed' to continue"
echo ""
echo "View nginx logs:"
echo "  docker compose logs -f nginx"
echo ""
echo "Stop nginx:"
echo "  docker compose down"
echo ""
