// Example service configuration using the config loader
// services/opc-service/config.example.js

import { loadConfig, loadDatabaseConfig } from '../lib/config-loader.js';

export const config = loadConfig('opc-service', {
  port: {
    env: 'OPC_PORT',
    type: 'number',
    default: 8890,
    required: false,
  },
  newApiBaseUrl: {
    env: 'NEW_API_BASE_URL',
    required: true,
  },
  publicUrl: {
    env: 'OPC_PUBLIC_URL',
    required: true,
  },
  redirectUri: {
    env: 'OPC_SSO_REDIRECT_URI',
    required: false,
  },
  internalToken: {
    env: 'OPC_SSO_INTERNAL_TOKEN',
    required: true,
  },
  sessionSecret: {
    env: 'SESSION_SECRET',
    required: true,
  },
  cookieMaxAge: {
    env: 'COOKIE_MAX_AGE',
    type: 'number',
    default: 28800,
    required: false,
  },
  logLevel: {
    env: 'LOG_LEVEL',
    default: 'info',
    required: false,
  },
  requestTimeoutMs: {
    env: 'OPC_REQUEST_TIMEOUT_MS',
    type: 'number',
    default: 30000,
    required: false,
  },
});

// Database configuration
export const dbConfig = loadDatabaseConfig('OPC');

// Usage in server.js:
// import { config, dbConfig } from './config.js';
// const server = createServer({ ...config });
