#!/usr/bin/env bash
set -euo pipefail

# 测试 4: 独立迁移能力

PGHOST=localhost
PGPORT=55432
PGUSER=postgres
BACKUP_DIR="/tmp/zsxq_backup_test_$(date +%s)"

echo "=== 测试 4: 独立迁移和恢复 ==="

mkdir -p "$BACKUP_DIR"

# 备份每个数据库
for db in super_wallet opc_core super_canvas; do
    echo "备份 $db..."
    pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -Fc -f "$BACKUP_DIR/${db}.dump" $db
    if [ $? -eq 0 ]; then
        echo "✅ $db 备份成功"
    else
        echo "❌ $db 备份失败"
        exit 1
    fi
done

# 验证备份文件
echo ""
echo "验证备份文件..."
for db in super_wallet opc_core super_canvas; do
    if [ -f "$BACKUP_DIR/${db}.dump" ]; then
        size=$(stat -c%s "$BACKUP_DIR/${db}.dump" 2>/dev/null || stat -f%z "$BACKUP_DIR/${db}.dump" 2>/dev/null || echo 0)
        if [ $size -gt 1024 ]; then
            echo "✅ $db 备份文件有效 (${size} bytes)"
        else
            echo "❌ $db 备份文件过小或无效"
            exit 1
        fi
    else
        echo "❌ $db 备份文件不存在"
        exit 1
    fi
done

# 测试恢复到新数据库（验证独立性）
echo ""
echo "测试独立恢复..."
test_db="super_wallet_restore_test"
echo "创建测试数据库 $test_db..."
psql -h $PGHOST -p $PGPORT -U $PGUSER -c "DROP DATABASE IF EXISTS $test_db;" 2>/dev/null || true
psql -h $PGHOST -p $PGPORT -U $PGUSER -c "CREATE DATABASE $test_db;"

echo "恢复 super_wallet 到 $test_db..."
pg_restore -h $PGHOST -p $PGPORT -U $PGUSER -d $test_db "$BACKUP_DIR/super_wallet.dump" 2>/dev/null || true

# 验证恢复后的数据
table_count=$(psql -h $PGHOST -p $PGPORT -U $PGUSER -d $test_db -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';")
if [ "$table_count" -gt 0 ]; then
    echo "✅ 独立恢复成功 (恢复了 $table_count 个表)"
    # 清理测试数据库
    psql -h $PGHOST -p $PGPORT -U $PGUSER -c "DROP DATABASE $test_db;"
else
    echo "❌ 独立恢复失败（未找到表）"
    exit 1
fi

echo ""
echo "清理备份文件..."
rm -rf "$BACKUP_DIR"

echo ""
echo "✅ 测试 4 通过: 可独立迁移和恢复"
