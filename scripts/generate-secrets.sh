#!/bin/bash
# scripts/generate-secrets.sh
# 生成所有必需的密钥和密码

set -e

echo "# ============================================"
echo "# 生成的密钥配置"
echo "# ============================================"
echo "# 生成时间: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "# ⚠️  请将这些值复制到 .env.local 或环境变量配置中"
echo "# ⚠️  不要提交到 git 或共享到公开渠道"
echo "# ============================================"
echo ""

echo "# 内部服务认证（64+ 字符）"
echo "SERVICE_TOKEN_SECRET=$(openssl rand -base64 48)"
echo ""

echo "# JWT 签名密钥（32+ 字符）"
echo "JWT_SECRET=$(openssl rand -base64 24)"
echo ""

echo "# 会话签名密钥（32+ 字符）"
echo "SESSION_SECRET=$(openssl rand -base64 24)"
echo ""

echo "# OPC 内部认证令牌（32+ 字符）"
echo "OPC_SSO_INTERNAL_TOKEN=$(openssl rand -base64 24)"
echo ""

echo "# 数据库密码（16+ 字符）"
echo "NEW_API_DB_PASSWORD=$(openssl rand -base64 16)"
echo "OPC_DB_PASSWORD=$(openssl rand -base64 16)"
echo "CANVAS_DB_PASSWORD=$(openssl rand -base64 16)"
echo ""

echo "# 对象存储密钥（如需要）"
echo "# S3_SECRET_KEY=$(openssl rand -base64 32)"
echo ""

echo "# ============================================"
echo "# 使用方式："
echo "# 1. 将以上输出追加到 .env.local:"
echo "#    ./scripts/generate-secrets.sh >> .env.local"
echo "#"
echo "# 2. 或手动复制需要的项到配置文件"
echo "# ============================================"
