-- 测试 3: Canvas 对 Wallet 只读权限
-- 执行: psql -h localhost -p 55432 -U postgres -f test-canvas-readonly.sql

\echo '=== 测试 3: Canvas 对 Wallet 只读权限 ==='

-- 切换到 super_canvas
\c super_canvas

-- 设置为 canvas_app 角色
SET ROLE canvas_app;

\echo ''
\echo '测试 3.1: 读取 super_wallet.users（应成功）'
SELECT COUNT(*) AS user_count FROM super_wallet.users;

\echo ''
\echo '测试 3.2: 读取 super_wallet.accounts（应成功）'
SELECT COUNT(*) AS account_count FROM super_wallet.accounts;

\echo ''
\echo '测试 3.3: 尝试写入 super_wallet.users（应失败）'
DO $$
BEGIN
    INSERT INTO super_wallet.users (username, email, role) 
    VALUES ('test_user', 'test@example.com', 'user');
    RAISE EXCEPTION '❌ 错误: 应该被权限拒绝但却成功了';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '✅ 写入被正确拒绝';
END $$;

\echo ''
\echo '测试 3.4: 尝试修改 super_wallet.accounts（应失败）'
DO $$
BEGIN
    UPDATE super_wallet.accounts SET balance = 1000000 WHERE id = 1;
    RAISE EXCEPTION '❌ 错误: 应该被权限拒绝但却成功了';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '✅ 更新被正确拒绝';
END $$;

\echo ''
\echo '测试 3.5: 尝试删除 super_wallet 数据（应失败）'
DO $$
BEGIN
    DELETE FROM super_wallet.users WHERE id = 999;
    RAISE EXCEPTION '❌ 错误: 应该被权限拒绝但却成功了';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '✅ 删除被正确拒绝';
END $$;

-- 重置角色
RESET ROLE;

\echo ''
\echo '✅ 测试 3 通过: Canvas 只读权限正确'
