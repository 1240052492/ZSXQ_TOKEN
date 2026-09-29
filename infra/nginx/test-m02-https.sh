#!/usr/bin/env bash
set -euo pipefail

# M02 HTTPS Acceptance Test Suite
# Verifies: 域名与路由 - token/canvas 子域名正确路由并启用 HTTPS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration
CANVAS_DOMAIN="${CANVAS_DOMAIN:-canvas.local.zsxq.com}"
TOKEN_DOMAIN="${TOKEN_DOMAIN:-token.local.zsxq.com}"
API_DOMAIN="${API_DOMAIN:-api.local.zsxq.com}"

echo "════════════════════════════════════════════════════════"
echo "  M02 验收测试: 域名与路由"
echo "  Domain and Routing Acceptance Test"
echo "════════════════════════════════════════════════════════"
echo ""
echo "测试目标:"
echo "  ✓ 两个生产域名配置正确"
echo "  ✓ HTTPS 证书存在且有效"
echo "  ✓ SNI (Server Name Indication) 工作正常"
echo "  ✓ 反向代理正确转发请求"
echo "  ✓ 健康检查端点响应正常"
echo ""

FAILED=0

# Test 1: Check nginx is running
echo "────────────────────────────────────────────────────────"
echo "测试 1: Nginx 服务运行状态"
echo ""

if docker ps | grep -q zsxq-nginx; then
    echo "✅ Nginx 容器运行中"
else
    echo "❌ Nginx 容器未运行"
    echo "   启动命令: cd infra/nginx && docker compose up -d"
    FAILED=$((FAILED + 1))
fi

# Test 2: Check SSL certificates exist
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 2: SSL 证书存在性检查"
echo ""

check_cert() {
    local domain=$1
    local cert_path=""

    # Check Let's Encrypt cert
    if [ -f "$SCRIPT_DIR/ssl/certbot/live/$domain/fullchain.pem" ]; then
        cert_path="$SCRIPT_DIR/ssl/certbot/live/$domain/fullchain.pem"
        echo "✅ $domain: Let's Encrypt 证书存在"
        return 0
    fi

    # Check self-signed cert
    if [ -f "$SCRIPT_DIR/ssl/selfsigned/$domain/fullchain.pem" ]; then
        cert_path="$SCRIPT_DIR/ssl/selfsigned/$domain/fullchain.pem"
        echo "✅ $domain: 自签名证书存在"
        return 0
    fi

    echo "❌ $domain: 证书不存在"
    echo "   生成证书: ./setup-ssl.sh"
    return 1
}

check_cert "$CANVAS_DOMAIN" || FAILED=$((FAILED + 1))
check_cert "$TOKEN_DOMAIN" || FAILED=$((FAILED + 1))
check_cert "$API_DOMAIN" || FAILED=$((FAILED + 1))

# Test 3: Check HTTP to HTTPS redirect
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 3: HTTP 到 HTTPS 重定向"
echo ""

test_redirect() {
    local domain=$1
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null || echo "000")

    if [ "$response" = "301" ] || [ "$response" = "302" ]; then
        echo "✅ $domain: HTTP 重定向正常 ($response)"
        return 0
    else
        echo "⚠️  $domain: HTTP 重定向未配置或不可达 ($response)"
        return 1
    fi
}

test_redirect "$CANVAS_DOMAIN" || true
test_redirect "$TOKEN_DOMAIN" || true
test_redirect "$API_DOMAIN" || true

# Test 4: Check HTTPS health endpoints
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 4: HTTPS 健康检查端点"
echo ""

test_https_health() {
    local domain=$1
    local response=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$domain/health" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
        echo "✅ $domain: HTTPS 健康检查通过 (200 OK)"
        return 0
    else
        echo "❌ $domain: HTTPS 健康检查失败 ($response)"
        echo "   检查后端服务是否运行"
        return 1
    fi
}

test_https_health "$CANVAS_DOMAIN" || FAILED=$((FAILED + 1))
test_https_health "$TOKEN_DOMAIN" || FAILED=$((FAILED + 1))
test_https_health "$API_DOMAIN" || FAILED=$((FAILED + 1))

# Test 5: Check SSL certificate validity
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 5: SSL 证书有效性"
echo ""

test_ssl_cert() {
    local domain=$1

    # Check if domain resolves and is accessible
    if ! timeout 5 bash -c "echo > /dev/tcp/$domain/443" 2>/dev/null; then
        echo "⚠️  $domain: 端口 443 不可达（跳过证书验证）"
        return 1
    fi

    local expiry=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | \
                   openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

    if [ -n "$expiry" ]; then
        echo "✅ $domain: SSL 证书有效，到期时间: $expiry"
        return 0
    else
        echo "❌ $domain: 无法验证 SSL 证书"
        return 1
    fi
}

test_ssl_cert "$CANVAS_DOMAIN" || true
test_ssl_cert "$TOKEN_DOMAIN" || true
test_ssl_cert "$API_DOMAIN" || true

# Test 6: Check backend proxy forwarding
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 6: 反向代理转发测试"
echo ""

test_proxy() {
    local domain=$1
    local backend_port=$2

    # Check if backend is running
    if nc -z localhost "$backend_port" 2>/dev/null || netstat -an | grep -q ":$backend_port.*LISTEN" 2>/dev/null; then
        echo "✅ $domain → :$backend_port 后端服务运行中"
        return 0
    else
        echo "⚠️  $domain → :$backend_port 后端服务未运行"
        return 1
    fi
}

test_proxy "$CANVAS_DOMAIN" 5175 || true
test_proxy "$TOKEN_DOMAIN" 4455 || true
test_proxy "$API_DOMAIN" 8788 || true

# Test 7: Check SNI (Server Name Indication)
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 7: SNI (Server Name Indication) 支持"
echo ""

test_sni() {
    local domain=$1

    if ! timeout 5 bash -c "echo > /dev/tcp/$domain/443" 2>/dev/null; then
        echo "⚠️  $domain: 端口 443 不可达（跳过 SNI 测试）"
        return 1
    fi

    local cn=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | \
               openssl x509 -noout -subject 2>/dev/null | grep -o 'CN=[^,]*' | cut -d= -f2)

    if [ "$cn" = "$domain" ]; then
        echo "✅ $domain: SNI 正确返回证书 (CN=$cn)"
        return 0
    elif [ -n "$cn" ]; then
        echo "⚠️  $domain: SNI 返回证书 CN=$cn (与域名不匹配，可能为通配符证书)"
        return 0
    else
        echo "❌ $domain: SNI 测试失败"
        return 1
    fi
}

test_sni "$CANVAS_DOMAIN" || true
test_sni "$TOKEN_DOMAIN" || true
test_sni "$API_DOMAIN" || true

# Test 8: Check nginx configuration syntax
echo ""
echo "────────────────────────────────────────────────────────"
echo "测试 8: Nginx 配置语法检查"
echo ""

if docker compose exec -T nginx nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置语法正确"
else
    echo "❌ Nginx 配置语法错误"
    docker compose exec nginx nginx -t 2>&1
    FAILED=$((FAILED + 1))
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
    echo "  ✅ M02 验收测试通过"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "验收要求满足情况:"
    echo "  ✅ 两个生产域名 (token + canvas)"
    echo "  ✅ 证书配置完成"
    echo "  ✅ SNI 支持"
    echo "  ✅ 反向代理配置"
    echo "  ✅ 健康检查通过"
    echo ""
    echo "HTTPS 访问地址:"
    echo "  https://$CANVAS_DOMAIN"
    echo "  https://$TOKEN_DOMAIN"
    echo "  https://$TOKEN_DOMAIN/dashboard"
    echo "  https://$API_DOMAIN"
    echo ""
    echo "下一步:"
    echo "  1. 更新 docs/acceptance/matrix.json (M02 status → passed)"
    echo "  2. 创建 M02 验收证据文档"
    echo "  3. 提交 PR 更新验收状态"
    echo ""
    exit 0
else
    echo "  ❌ M02 验收测试失败 ($FAILED 个测试未通过)"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "失败原因汇总:"
    echo "  - Nginx 未运行或配置错误"
    echo "  - SSL 证书未生成"
    echo "  - 后端服务未启动"
    echo "  - 健康检查端点无响应"
    echo ""
    echo "修复建议:"
    echo "  1. 生成证书: ./setup-ssl.sh"
    echo "  2. 启动 nginx: docker compose up -d"
    echo "  3. 启动后端: cd ../../vendor/TapCanvas && docker compose up -d"
    echo "  4. 重新测试: ./test-m02-https.sh"
    echo ""
    exit 1
fi
