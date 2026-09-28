// scripts/validate-env.mjs
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

// 环境变量定义
const ENV_SCHEMA = {
  // 服务配置
  NODE_ENV: { required: false, pattern: /^(development|production|test)$/ },
  LOG_LEVEL: { required: false, pattern: /^(debug|info|warn|error)$/ },

  // 数据库（至少需要一种配置方式）
  NEW_API_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },
  NEW_API_DB_HOST: { required: false },
  NEW_API_DB_PORT: { required: false, pattern: /^\d+$/ },
  NEW_API_DB_NAME: { required: false },
  NEW_API_DB_USER: { required: false },
  NEW_API_DB_PASSWORD: { required: false, minLength: 8 },

  OPC_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },
  CANVAS_DATABASE_URL: { required: false, pattern: /^postgresql:\/\/.+/ },

  // 服务地址
  NEW_API_BASE_URL: { required: true, pattern: /^https?:\/\/.+/ },
  OPC_PUBLIC_URL: { required: true, pattern: /^https?:\/\/.+/ },

  // 密钥
  SERVICE_TOKEN_SECRET: { required: true, minLength: 64 },
  JWT_SECRET: { required: true, minLength: 32 },
  SESSION_SECRET: { required: true, minLength: 32 },
  OPC_SSO_INTERNAL_TOKEN: { required: true, minLength: 32 },

  // 端口
  NEW_API_PORT: { required: false, pattern: /^\d+$/ },
  OPC_PORT: { required: false, pattern: /^\d+$/ },
  PLATFORM_GATEWAY_PORT: { required: false, pattern: /^\d+$/ },
};

const errors = [];
const warnings = [];

// 检查 .env 文件是否存在
const envPath = join(projectRoot, '.env');
const envLocalPath = join(projectRoot, '.env.local');

if (!existsSync(envPath) && !existsSync(envLocalPath)) {
  warnings.push('.env 和 .env.local 文件都不存在，将使用系统环境变量');
} else if (existsSync(envLocalPath)) {
  console.log(`✓ 找到 .env.local 文件`);
} else if (existsSync(envPath)) {
  console.log(`✓ 找到 .env 文件`);
}

// 验证必填项
for (const [key, spec] of Object.entries(ENV_SCHEMA)) {
  const value = process.env[key];

  if (spec.required && !value) {
    errors.push(`缺少必填环境变量: ${key}`);
    continue;
  }

  if (!value) continue;

  // 验证格式
  if (spec.pattern && !spec.pattern.test(value)) {
    errors.push(`${key} 格式不正确，期望匹配: ${spec.pattern}`);
  }

  // 验证最小长度
  if (spec.minLength && value.length < spec.minLength) {
    errors.push(`${key} 长度不足，最少需要 ${spec.minLength} 字符（当前: ${value.length}）`);
  }

  // 检查是否使用示例值
  if (value.includes('CHANGEME') || value.includes('example.com')) {
    warnings.push(`${key} 仍在使用示例值，请替换为实际配置`);
  }
}

// 检查数据库配置完整性
const hasNewApiDbUrl = Boolean(process.env.NEW_API_DATABASE_URL);
const hasNewApiDbParts = Boolean(
  process.env.NEW_API_DB_HOST &&
  process.env.NEW_API_DB_NAME &&
  process.env.NEW_API_DB_USER
);

if (!hasNewApiDbUrl && !hasNewApiDbParts) {
  errors.push('New API 数据库配置不完整：需要 NEW_API_DATABASE_URL 或完整的 DB_* 配置组');
}

// 生产环境额外检查
if (process.env.NODE_ENV === 'production') {
  if (process.env.NEW_API_BASE_URL?.startsWith('http://')) {
    errors.push('生产环境必须使用 HTTPS (NEW_API_BASE_URL)');
  }

  if (process.env.OPC_PUBLIC_URL?.startsWith('http://')) {
    errors.push('生产环境必须使用 HTTPS (OPC_PUBLIC_URL)');
  }

  if (process.env.LOG_LEVEL === 'debug') {
    warnings.push('生产环境不建议使用 debug 日志级别');
  }

  // 检查默认开发密钥
  const devSecrets = ['dev_', 'DO_NOT_USE_IN_PRODUCTION', 'dev-'];
  for (const [key, value] of Object.entries(process.env)) {
    if (key.includes('SECRET') || key.includes('PASSWORD') || key.includes('TOKEN')) {
      if (devSecrets.some(dev => value?.includes(dev))) {
        errors.push(`${key} 使用了开发环境默认值，生产环境禁止使用`);
      }
    }
  }
}

// 输出结果
console.log('\n' + '='.repeat(60));
console.log('环境变量验证结果');
console.log('='.repeat(60));

if (warnings.length > 0) {
  console.log('\n⚠️  警告 (' + warnings.length + '):');
  warnings.forEach(w => console.log(`  - ${w}`));
}

if (errors.length > 0) {
  console.log('\n❌ 错误 (' + errors.length + '):');
  errors.forEach(e => console.log(`  - ${e}`));
  console.log('\n请修复以上错误后重试');
  console.log('\n提示:');
  console.log('  1. 复制 .env.example 到 .env.local: cp .env.example .env.local');
  console.log('  2. 生成密钥: ./scripts/generate-secrets.sh');
  console.log('  3. 编辑 .env.local 填入实际配置');
  console.log('='.repeat(60) + '\n');
  process.exit(1);
}

console.log('\n✅ 环境变量验证通过');
console.log('='.repeat(60) + '\n');
