#!/usr/bin/env bash
set -euo pipefail

# ZSXQ Token 项目快速启动脚本
# 用途: 一键启动测试环境并验证核心服务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TAPCANVAS_ROOT="${PROJECT_ROOT}/vendor/TapCanvas"

echo "=== ZSXQ Token 快速启动 ==="
echo "项目根目录: ${PROJECT_ROOT}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未安装 Docker"
    exit 1
fi

# 检查 PostgreSQL 是否已运行
echo "1. 检查 PostgreSQL..."
if docker ps | grep -q postgres-postgres-1; then
    echo "✅ PostgreSQL 已运行"
    PG_RUNNING=1
else
    echo "⚠️  PostgreSQL 未运行，启动中..."
    cd "${PROJECT_ROOT}/infra/postgres"
    if [ -z "${ZSXQ_PG_ADMIN_PASSWORD:-}" ]; then
        echo "❌ 错误: 需要设置环境变量 ZSXQ_PG_ADMIN_PASSWORD"
        echo "   export ZSXQ_PG_ADMIN_PASSWORD='your-strong-password'"
        exit 1
    fi
    docker compose up -d
    echo "⏳ 等待 PostgreSQL 就绪..."
    sleep 10
    PG_RUNNING=1
fi

# 检查 TapCanvas .env
echo ""
echo "2. 检查 TapCanvas 配置..."
ENV_FILE="${TAPCANVAS_ROOT}/apps/hono-api/.env"
if [ ! -f "${ENV_FILE}" ]; then
    echo "⚠️  未找到 .env 文件，从示例创建..."
    if [ -f "${ENV_FILE}.example" ]; then
        cp "${ENV_FILE}.example" "${ENV_FILE}"
        echo "✅ 已创建 .env 文件"
        echo "⚠️  请编辑 ${ENV_FILE} 填入必需配置"
        echo "   最少需要配置:"
        echo "   - NEW_API_INTERNAL_TOKEN"
        echo "   - NEW_API_SSO_INTERNAL_TOKEN"
        echo "   - NEW_API_SESSION_SECRET"
        echo "   - NEW_API_CRYPTO_SECRET"
        echo "   - NEW_API_ROOT_PASSWORD"
        echo ""
        echo "按 Enter 继续编辑配置，或 Ctrl+C 退出..."
        read
        ${EDITOR:-nano} "${ENV_FILE}"
    else
        echo "❌ 未找到 .env.example"
        exit 1
    fi
else
    echo "✅ 配置文件存在"
fi

# 询问启动模式
echo ""
echo "3. 选择启动模式:"
echo "   1) 完整技术栈 (推荐，包含 web/api/new-api/workers)"
echo "   2) 核心服务 (postgres/redis/new-api/api/web)"
echo "   3) 仅数据库测试 (跳过 TapCanvas 服务)"
echo ""
read -p "请选择 [1-3]: " MODE

case $MODE in
    1)
        echo ""
        echo "启动完整技术栈..."
        cd "${TAPCANVAS_ROOT}"
        docker compose up -d
        STARTED_SERVICES="full"
        ;;
    2)
        echo ""
        echo "启动核心服务..."
        cd "${TAPCANVAS_ROOT}"
        docker compose up -d postgres redis new-api api web
        STARTED_SERVICES="core"
        ;;
    3)
        echo ""
        echo "仅使用数据库，跳过 TapCanvas 服务"
        STARTED_SERVICES="db-only"
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

# 等待服务就绪
if [ "${STARTED_SERVICES}" != "db-only" ]; then
    echo ""
    echo "⏳ 等待服务启动（这可能需要几分钟）..."
    sleep 20
    
    echo ""
    echo "4. 检查服务状态..."
    cd "${TAPCANVAS_ROOT}"
    docker compose ps
fi

# 输出访问信息
echo ""
echo "=== 服务访问信息 ==="
echo ""

if [ "${PG_RUNNING}" = "1" ]; then
    echo "📊 PostgreSQL:"
    echo "   地址: localhost:55432"
    echo "   用户: postgres"
    echo "   密码: \$ZSXQ_PG_ADMIN_PASSWORD"
    echo "   连接: psql -h localhost -p 55432 -U postgres"
    echo ""
fi

if [ "${STARTED_SERVICES}" = "full" ] || [ "${STARTED_SERVICES}" = "core" ]; then
    echo "🌐 Web UI:"
    echo "   http://localhost:5175"
    echo ""
    echo "🔌 API:"
    echo "   http://localhost:8788"
    echo "   健康检查: http://localhost:8788/health/version"
    echo ""
    echo "💰 New API:"
    echo "   http://localhost:4455"
    echo "   管理面板: http://localhost:4455/dashboard"
    echo "   用户名: admin"
    echo "   密码: (见 .env 中的 NEW_API_ROOT_PASSWORD)"
    echo ""
fi

if [ "${STARTED_SERVICES}" = "full" ]; then
    echo "🤖 Agents Bridge:"
    echo "   http://localhost:8799"
    echo ""
    echo "📦 Redis:"
    echo "   localhost:6379"
    echo ""
fi

echo "=== 常用命令 ==="
echo ""
echo "查看日志:"
if [ "${STARTED_SERVICES}" != "db-only" ]; then
    echo "  cd ${TAPCANVAS_ROOT}"
    echo "  docker compose logs -f api"
    echo "  docker compose logs -f web"
    echo "  docker compose logs -f new-api"
    echo ""
fi
echo "停止服务:"
if [ "${STARTED_SERVICES}" != "db-only" ]; then
    echo "  cd ${TAPCANVAS_ROOT} && docker compose down"
fi
echo "  cd ${PROJECT_ROOT}/infra/postgres && docker compose down"
echo ""
echo "数据库验证 (M05):"
echo "  psql -h localhost -p 55432 -U postgres"
echo "  postgres=# \l                    # 列出数据库"
echo "  postgres=# \c super_wallet       # 切换到钱包库"
echo "  super_wallet=# \dt               # 查看表"
echo ""
echo "=== 启动完成 ==="
