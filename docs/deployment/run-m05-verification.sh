#!/usr/bin/env bash
set -euo pipefail

# M05 完整验证套件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════"
echo "  M05 数据库隔离验收验证"
echo "  Three-Database Three-Account Isolation Verification"
echo "════════════════════════════════════════════════════════"
echo ""

# 检查环境
if [ -z "${ZSXQ_PG_ADMIN_PASSWORD:-}" ]; then
    echo "❌ 错误: 未设置 ZSXQ_PG_ADMIN_PASSWORD"
    echo "   请执行: export ZSXQ_PG_ADMIN_PASSWORD='your-password'"
    exit 1
fi

export PGPASSWORD="${ZSXQ_PG_ADMIN_PASSWORD}"

# 检查数据库连接
echo "检查数据库连接..."
if ! psql -h localhost -p 55432 -U postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo "❌ 错误: 无法连接到 PostgreSQL (localhost:55432)"
    echo "   请确保数据库已启动:"
    echo "   cd infra/postgres && docker compose up -d"
    exit 1
fi

echo "✅ 数据库连接正常"
echo ""

# 运行测试
echo "────────────────────────────────────────────────────────"
bash "$SCRIPT_DIR/test-database-isolation.sh"
echo ""

echo "────────────────────────────────────────────────────────"
bash "$SCRIPT_DIR/test-role-isolation.sh"
echo ""

echo "────────────────────────────────────────────────────────"
psql -h localhost -p 55432 -U postgres -f "$SCRIPT_DIR/test-canvas-readonly.sql"
echo ""

echo "────────────────────────────────────────────────────────"
bash "$SCRIPT_DIR/test-independent-migration.sh"
echo ""

echo "════════════════════════════════════════════════════════"
echo "  ✅ M05 验收通过"
echo "════════════════════════════════════════════════════════"
echo ""
echo "验收证据已记录在:"
echo "  - docs/development/evidence/M05-database-isolation.md"
echo "  - migrations/super_canvas/001_init.sql"
echo "  - migrations/opc_core/001_init.sql"
echo ""
echo "验收矩阵状态:"
echo "  - ID: M05"
echo "  - Status: passed"
echo "  - Verified by: @claude"
echo "  - Verified at: 2026-09-29"
echo ""
echo "查看完整验收矩阵:"
echo "  cat docs/acceptance/matrix.json | jq '.items[] | select(.id==\"M05\")'"
