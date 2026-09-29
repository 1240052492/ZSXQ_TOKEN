# HTTPS Deployment Guide

Complete guide for deploying ZSXQ_TOKEN services with HTTPS/SSL support.

## Overview

This directory provides HTTPS reverse proxy configuration using Nginx with support for:

- **Let's Encrypt** production certificates (for public domains)
- **Self-signed** certificates (for development/testing)
- Three-domain architecture: canvas, token, api
- Automatic HTTP to HTTPS redirect
- Health checks and monitoring
- WebSocket support

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Nginx (443)                          │
│  ┌─────────────┬─────────────────┬──────────────────────┐  │
│  │   canvas    │      token      │        api           │  │
│  │ :443 → 5175 │  :443 → 4455   │   :443 → 8788       │  │
│  └─────────────┴─────────────────┴──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ↓                ↓                    ↓
    ┌──────────┐    ┌──────────┐        ┌──────────┐
    │ Web UI   │    │ New API  │        │Hono API  │
    │   5175   │    │   4455   │        │   8788   │
    └──────────┘    └──────────┘        └──────────┘
```

## Domain Mapping

| Domain | Service | Backend Port | Purpose |
|--------|---------|--------------|---------|
| `canvas.yourdomain.com` | Web UI | 5175 | Canvas editor frontend |
| `token.yourdomain.com` | New API | 4455 | Account, wallet, SSO |
| `api.yourdomain.com` | Hono API | 8788 | Canvas backend API |

## Quick Start (Local Development)

### Option 1: Automated Setup

```bash
cd infra/nginx
./quick-https-setup.sh
```

This will:
1. Generate self-signed certificates
2. Configure nginx for local domains
3. Update `/etc/hosts` (requires sudo)
4. Start nginx with HTTPS

**Access URLs:**
- https://canvas.local.zsxq.com
- https://token.local.zsxq.com
- https://api.local.zsxq.com

### Option 2: Manual Setup

```bash
# 1. Generate certificates
cd infra/nginx
./setup-ssl.sh
# Choose option 2 (self-signed)

# 2. Update nginx configurations
# Edit conf.d/*.conf to replace "yourdomain.com" with your domain

# 3. Update /etc/hosts
sudo tee -a /etc/hosts << EOF
127.0.0.1 canvas.local.zsxq.com
127.0.0.1 token.local.zsxq.com
127.0.0.1 api.local.zsxq.com
EOF

# 4. Start nginx
docker compose up -d
```

## Production Deployment

### Prerequisites

1. **Public domains** pointing to your server:
   - `canvas.yourdomain.com`
   - `token.yourdomain.com`
   - `api.yourdomain.com`

2. **DNS A records** configured:
   ```
   canvas  IN  A  <your-server-ip>
   token   IN  A  <your-server-ip>
   api     IN  A  <your-server-ip>
   ```

3. **Port 80 and 443** accessible from internet

### Let's Encrypt Setup

```bash
cd infra/nginx

# Run SSL setup wizard
./setup-ssl.sh

# Choose option 1 (Let's Encrypt)
# Enter your domains and email

# Update nginx configurations with your domains
sed -i 's/yourdomain.com/example.com/g' conf.d/*.conf

# Start nginx
docker compose up -d

# Verify certificates
docker compose logs certbot
```

### Certificate Renewal

Let's Encrypt certificates auto-renew every 12 hours. Manual renewal:

```bash
docker compose exec certbot certbot renew
docker compose restart nginx
```

## Configuration Files

### Core Files

```
infra/nginx/
├── docker-compose.yml          # Nginx + Certbot containers
├── nginx.conf                  # Main nginx configuration
├── conf.d/
│   ├── canvas.conf            # Canvas UI proxy
│   ├── token.conf             # Token API proxy
│   └── api.conf               # Hono API proxy
├── setup-ssl.sh               # SSL certificate wizard
├── quick-https-setup.sh       # One-command local setup
└── ssl/                       # SSL certificates
    ├── certbot/               # Let's Encrypt certs
    ├── selfsigned/            # Self-signed certs
    └── www/                   # ACME challenge files
```

### Environment Variables

Update backend services to use HTTPS URLs:

**vendor/TapCanvas/apps/hono-api/.env:**
```bash
# Update these values
NEW_API_PUBLIC_BASE_URL=https://token.yourdomain.com
VITE_GITHUB_REDIRECT_URI=https://canvas.yourdomain.com/auth/callback
TAPCANVAS_SSO_REDIRECT_URI=https://canvas.yourdomain.com/auth/sso/callback
SESSION_COOKIE_DOMAIN=.yourdomain.com
```

## Testing

### Health Checks

```bash
# Test nginx is running
curl -k https://canvas.yourdomain.com/health

# Test backend services
curl -k https://token.yourdomain.com/health
curl -k https://api.yourdomain.com/health

# Test HTTP redirect
curl -I http://canvas.yourdomain.com
# Should return: HTTP/1.1 301 Moved Permanently
```

### SSL Certificate Verification

```bash
# Check certificate details
openssl s_client -connect canvas.yourdomain.com:443 -servername canvas.yourdomain.com

# Check expiry date
echo | openssl s_client -connect canvas.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Verify certificate chain
curl -vI https://canvas.yourdomain.com
```

### Full Stack Test

```bash
# 1. Ensure backend services are running
docker ps | grep zsxq

# 2. Test canvas UI
curl -k https://canvas.yourdomain.com

# 3. Test token API
curl -k https://token.yourdomain.com/dashboard

# 4. Test hono API
curl -k https://api.yourdomain.com/health
```

## Troubleshooting

### Nginx won't start

```bash
# Check configuration syntax
docker run --rm -v "$(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:1.25-alpine nginx -t

# Check logs
docker compose logs nginx

# Common issues:
# - Certificate files not found
# - Port 80/443 already in use
# - Invalid domain in conf.d/*.conf
```

### Certificate not found

```bash
# Verify certificate files exist
ls -la ssl/certbot/live/canvas.yourdomain.com/
ls -la ssl/selfsigned/canvas.local.zsxq.com/

# Regenerate self-signed certificates
./setup-ssl.sh
```

### Backend service unreachable

```bash
# Check if backend is listening
netstat -tuln | grep -E '5175|4455|8788'

# Test direct backend access
curl http://localhost:5175
curl http://localhost:4455/health
curl http://localhost:8788/health

# Check nginx proxy logs
docker compose logs nginx | grep proxy
```

### Browser shows NET::ERR_CERT_AUTHORITY_INVALID

This is expected for self-signed certificates. Options:

1. **Click "Advanced" → "Proceed"** (development only)
2. **Add certificate to trust store:**
   ```bash
   # Linux
   sudo cp ssl/selfsigned/canvas.local.zsxq.com/fullchain.pem \
     /usr/local/share/ca-certificates/zsxq-canvas.crt
   sudo update-ca-certificates
   
   # macOS
   sudo security add-trusted-cert -d -r trustRoot \
     -k /Library/Keychains/System.keychain \
     ssl/selfsigned/canvas.local.zsxq.com/fullchain.pem
   ```
3. **Use Let's Encrypt** for production

## Security Considerations

### Current Configuration

- ✅ TLS 1.2 and 1.3 only
- ✅ Strong cipher suites
- ✅ HSTS enabled (max-age: 1 year)
- ✅ Security headers (X-Frame-Options, X-Content-Type-Options)
- ✅ Client body size limit: 100MB
- ✅ Gzip compression enabled

### Recommendations

1. **Use Let's Encrypt in production** (not self-signed)
2. **Restrict /dashboard to internal IPs:**
   ```nginx
   location /dashboard {
       allow 10.0.0.0/8;
       deny all;
       proxy_pass http://host.docker.internal:4455;
   }
   ```
3. **Enable rate limiting:**
   ```nginx
   limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
   limit_req zone=api burst=20;
   ```
4. **Monitor SSL Labs score:** https://www.ssllabs.com/ssltest/

## M02 Acceptance Verification

This configuration satisfies **M02: 域名与路由** requirements:

- ✅ Two production domains (token + canvas)
- ✅ HTTPS certificates (Let's Encrypt or self-signed)
- ✅ SNI support (multiple domains on same IP)
- ✅ Reverse proxy configured
- ✅ Health check endpoints

**Verification command:**
```bash
./test-m02-https.sh  # Coming soon
```

## Maintenance

### View logs

```bash
# Nginx access/error logs
docker compose logs -f nginx
tail -f logs/access.log
tail -f logs/error.log

# Certificate renewal logs
docker compose logs certbot
```

### Restart nginx

```bash
docker compose restart nginx

# Or reload config without downtime
docker compose exec nginx nginx -s reload
```

### Update SSL certificates

```bash
# Let's Encrypt renewal (automatic)
docker compose exec certbot certbot renew

# Regenerate self-signed
./setup-ssl.sh
docker compose restart nginx
```

### Backup certificates

```bash
# Backup Let's Encrypt
tar czf letsencrypt-backup-$(date +%Y%m%d).tar.gz ssl/certbot/

# Backup self-signed
tar czf selfsigned-backup-$(date +%Y%m%d).tar.gz ssl/selfsigned/
```

## Next Steps

1. ✅ Complete nginx HTTPS setup
2. ⏳ Update backend environment variables with HTTPS URLs
3. ⏳ Start all services and test end-to-end HTTPS flow
4. ⏳ Create M02 acceptance evidence document
5. ⏳ Update acceptance matrix for M02 status

## Support

For issues or questions:
- Check troubleshooting section above
- Review nginx logs: `docker compose logs nginx`
- Test certificate: `openssl s_client -connect <domain>:443`
- Validate config: `docker compose exec nginx nginx -t`
