// services/lib/config-loader.js

/**
 * 统一配置加载器
 * 从环境变量加载配置，支持必填项验证和默认值
 *
 * @param {string} serviceName - 服务名称，用于错误消息
 * @param {Object} schema - 配置模式定义
 * @returns {Object} 加载的配置对象
 * @throws {Error} 当必填配置缺失时
 *
 * @example
 * const config = loadConfig('my-service', {
 *   port: { env: 'PORT', default: 3000, required: false },
 *   apiKey: { env: 'API_KEY', required: true },
 * });
 */
export function loadConfig(serviceName, schema) {
  const config = {};
  const missing = [];

  for (const [key, spec] of Object.entries(schema)) {
    const envKey = spec.env || key;
    const value = process.env[envKey];

    if (spec.required && !value) {
      missing.push(envKey);
      continue;
    }

    // 类型转换
    let finalValue = value ?? spec.default;

    if (finalValue !== undefined && spec.type === 'number') {
      finalValue = Number(finalValue);
      if (isNaN(finalValue)) {
        throw new Error(`${serviceName}: ${envKey} must be a valid number`);
      }
    }

    if (finalValue !== undefined && spec.type === 'boolean') {
      finalValue = finalValue === 'true' || finalValue === '1' || finalValue === true;
    }

    config[key] = finalValue;
  }

  if (missing.length > 0) {
    throw new Error(
      `${serviceName} missing required environment variables: ${missing.join(', ')}\n` +
      `Run 'npm run validate-env' to check your configuration.`
    );
  }

  return config;
}

/**
 * 加载数据库配置
 * 支持单一 DATABASE_URL 或分离的 DB_* 配置
 *
 * @param {string} prefix - 配置前缀，如 'NEW_API' 或 'OPC'
 * @returns {Object} 数据库配置对象
 */
export function loadDatabaseConfig(prefix) {
  const urlKey = `${prefix}_DATABASE_URL`;
  const url = process.env[urlKey];

  if (url) {
    return { connectionString: url };
  }

  // 使用分离配置
  const host = process.env[`${prefix}_DB_HOST`];
  const port = process.env[`${prefix}_DB_PORT`] || '5432';
  const database = process.env[`${prefix}_DB_NAME`];
  const user = process.env[`${prefix}_DB_USER`];
  const password = process.env[`${prefix}_DB_PASSWORD`];
  const ssl = process.env[`${prefix}_DB_SSL`] === 'true';

  if (!host || !database || !user) {
    throw new Error(
      `${prefix} database configuration incomplete: ` +
      `need ${urlKey} or complete ${prefix}_DB_* config group`
    );
  }

  const auth = password ? `${user}:${password}` : user;
  return {
    connectionString: `postgresql://${auth}@${host}:${port}/${database}${ssl ? '?sslmode=require' : ''}`,
    host,
    port: Number(port),
    database,
    user,
    password,
    ssl,
  };
}
