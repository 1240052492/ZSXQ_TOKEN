#!/usr/bin/env bash
set -euo pipefail

# 测试 1: 验证数据库隔离

PGHOST=localhost
PGPORT=55432
PGUSER=postgres

echo "=== 测试 1: 验证数据库隔离 ==="

# 检查三个数据库是否存在
for db in super_wallet opc_core super_canvas; do
    if psql -h $PGHOST -p $PGPORT -U $PGUSER -lqt | cut -d \| -f 1 | grep -qw $db; then
        echo "✅ 数据库 $db 存在"
    else
        echo "❌ 数据库 $db 不存在"
        exit 1
    fi
done

# 验证数据库之间没有交叉引用
echo ""
echo "检查数据库独立性..."

# 检查 super_canvas 不应该有 wallet 相关的本地表
wallet_tables=$(psql -h $PGHOST -p $PGPORT -U $PGUSER -d super_canvas -tAc "
    SELECT COUNT(*) 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename LIKE '%wallet%';
")

if [ "$wallet_tables" -eq 0 ]; then
    echo "✅ super_canvas 与 super_wallet 表隔离正确"
else
    echo "❌ super_canvas 中发现 $wallet_tables 个 wallet 相关表"
    exit 1
fi

echo ""
echo "✅ 测试 1 通过: 数据库隔离正确"
