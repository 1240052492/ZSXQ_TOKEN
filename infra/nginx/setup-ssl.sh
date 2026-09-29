#!/usr/bin/env bash
set -euo pipefail

# SSL Certificate Setup Script for ZSXQ_TOKEN Project
# Supports both Let's Encrypt production certificates and self-signed certificates for development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/ssl"
CERTBOT_DIR="$SSL_DIR/certbot"
SELFSIGNED_DIR="$SSL_DIR/selfsigned"

# Default domains
CANVAS_DOMAIN="${CANVAS_DOMAIN:-canvas.yourdomain.com}"
TOKEN_DOMAIN="${TOKEN_DOMAIN:-token.yourdomain.com}"
API_DOMAIN="${API_DOMAIN:-api.yourdomain.com}"
EMAIL="${SSL_EMAIL:-admin@yourdomain.com}"

echo "════════════════════════════════════════════════════════"
echo "  ZSXQ_TOKEN HTTPS/SSL Certificate Setup"
echo "════════════════════════════════════════════════════════"
echo ""

# Function to create self-signed certificates
create_selfsigned_cert() {
    local domain=$1
    local cert_dir="$SELFSIGNED_DIR/$domain"

    echo "Creating self-signed certificate for $domain..."
    mkdir -p "$cert_dir"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/privkey.pem" \
        -out "$cert_dir/fullchain.pem" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=ZSXQ/OU=Development/CN=$domain"

    if [ -f "$cert_dir/fullchain.pem" ] && [ -f "$cert_dir/privkey.pem" ]; then
        echo "✅ Self-signed certificate created for $domain"
        return 0
    else
        echo "❌ Failed to create self-signed certificate for $domain"
        return 1
    fi
}

# Function to obtain Let's Encrypt certificate
obtain_letsencrypt_cert() {
    local domain=$1

    echo "Obtaining Let's Encrypt certificate for $domain..."

    docker run --rm \
        -v "$CERTBOT_DIR:/etc/letsencrypt" \
        -v "$SSL_DIR/www:/var/www/certbot" \
        -p 80:80 \
        certbot/certbot certonly \
        --standalone \
        --agree-tos \
        --email "$EMAIL" \
        --no-eff-email \
        -d "$domain"

    if [ -f "$CERTBOT_DIR/live/$domain/fullchain.pem" ]; then
        echo "✅ Let's Encrypt certificate obtained for $domain"
        return 0
    else
        echo "❌ Failed to obtain Let's Encrypt certificate for $domain"
        return 1
    fi
}

# Menu
echo "Choose certificate type:"
echo "  1) Let's Encrypt (production, requires public domain)"
echo "  2) Self-signed (development/testing)"
echo "  3) Skip certificate setup"
echo ""
read -p "Enter choice [1-3]: " cert_choice

case $cert_choice in
    1)
        echo ""
        echo "Let's Encrypt Certificate Setup"
        echo "────────────────────────────────────────────────────────"
        echo "⚠️  Requirements:"
        echo "   - Domains must resolve to this server's public IP"
        echo "   - Port 80 must be accessible from internet"
        echo "   - Valid email address required"
        echo ""

        read -p "Canvas domain [$CANVAS_DOMAIN]: " input_canvas
        CANVAS_DOMAIN="${input_canvas:-$CANVAS_DOMAIN}"

        read -p "Token domain [$TOKEN_DOMAIN]: " input_token
        TOKEN_DOMAIN="${input_token:-$TOKEN_DOMAIN}"

        read -p "API domain [$API_DOMAIN]: " input_api
        API_DOMAIN="${input_api:-$API_DOMAIN}"

        read -p "Email address [$EMAIL]: " input_email
        EMAIL="${input_email:-$EMAIL}"

        echo ""
        echo "Will obtain certificates for:"
        echo "  - $CANVAS_DOMAIN"
        echo "  - $TOKEN_DOMAIN"
        echo "  - $API_DOMAIN"
        echo ""
        read -p "Continue? [y/N]: " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi

        mkdir -p "$CERTBOT_DIR" "$SSL_DIR/www"

        obtain_letsencrypt_cert "$CANVAS_DOMAIN" || true
        obtain_letsencrypt_cert "$TOKEN_DOMAIN" || true
        obtain_letsencrypt_cert "$API_DOMAIN" || true

        echo ""
        echo "✅ Let's Encrypt certificate setup complete"
        echo ""
        echo "Update nginx configurations to use:"
        echo "  /etc/nginx/ssl/certbot/live/<domain>/fullchain.pem"
        echo "  /etc/nginx/ssl/certbot/live/<domain>/privkey.pem"
        ;;

    2)
        echo ""
        echo "Self-Signed Certificate Setup"
        echo "────────────────────────────────────────────────────────"
        echo "⚠️  Self-signed certificates will trigger browser warnings"
        echo "   Only use for development/testing"
        echo ""

        read -p "Canvas domain [$CANVAS_DOMAIN]: " input_canvas
        CANVAS_DOMAIN="${input_canvas:-$CANVAS_DOMAIN}"

        read -p "Token domain [$TOKEN_DOMAIN]: " input_token
        TOKEN_DOMAIN="${input_token:-$TOKEN_DOMAIN}"

        read -p "API domain [$API_DOMAIN]: " input_api
        API_DOMAIN="${input_api:-$API_DOMAIN}"

        echo ""
        echo "Creating self-signed certificates for:"
        echo "  - $CANVAS_DOMAIN"
        echo "  - $TOKEN_DOMAIN"
        echo "  - $API_DOMAIN"
        echo ""

        mkdir -p "$SELFSIGNED_DIR"

        create_selfsigned_cert "$CANVAS_DOMAIN"
        create_selfsigned_cert "$TOKEN_DOMAIN"
        create_selfsigned_cert "$API_DOMAIN"

        echo ""
        echo "✅ Self-signed certificates created"
        echo ""
        echo "Update nginx configurations to use:"
        echo "  /etc/nginx/ssl/selfsigned/<domain>/fullchain.pem"
        echo "  /etc/nginx/ssl/selfsigned/<domain>/privkey.pem"
        ;;

    3)
        echo ""
        echo "Skipping certificate setup"
        echo "You can run this script later to generate certificates"
        exit 0
        ;;

    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Next Steps"
echo "════════════════════════════════════════════════════════"
echo ""
echo "1. Update DNS records to point domains to this server"
echo "2. Configure /etc/hosts for local testing:"
echo "   127.0.0.1  $CANVAS_DOMAIN"
echo "   127.0.0.1  $TOKEN_DOMAIN"
echo "   127.0.0.1  $API_DOMAIN"
echo ""
echo "3. Update nginx configurations with your actual domains"
echo "4. Start nginx:"
echo "   cd $SCRIPT_DIR"
echo "   docker compose up -d"
echo ""
echo "5. Test HTTPS access:"
echo "   https://$CANVAS_DOMAIN"
echo "   https://$TOKEN_DOMAIN"
echo "   https://$API_DOMAIN"
echo ""
