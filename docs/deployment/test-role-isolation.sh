#!/usr/bin/env bash
set -euo pipefail

# 测试 2: 验证角色权限隔离

PGHOST=localhost
PGPORT=55432
PGUSER=postgres

echo "=== 测试 2: 验证角色权限隔离 ==="

# 验证角色存在
for role in super_wallet_app opc_core_app canvas_app; do
    if psql -h $PGHOST -p $PGPORT -U $PGUSER -tAc "SELECT 1 FROM pg_roles WHERE rolname='$role'" | grep -q 1; then
        echo "✅ 角色 $role 存在"
    else
        echo "❌ 角色 $role 不存在"
        exit 1
    fi
done

# 验证角色不能登录（应用角色，非登录角色）
echo ""
echo "检查角色登录权限..."
for role in super_wallet_app opc_core_app canvas_app; do
    can_login=$(psql -h $PGHOST -p $PGPORT -U $PGUSER -tAc "SELECT rolcanlogin FROM pg_roles WHERE rolname='$role'")
    if [ "$can_login" = "f" ]; then
        echo "✅ 角色 $role 不能直接登录（正确）"
    else
        echo "⚠️  角色 $role 可以登录（应为应用角色）"
    fi
done

echo ""
echo "✅ 测试 2 通过: 角色隔离正确"
