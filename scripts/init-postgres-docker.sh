#!/bin/bash
# Docker-based PostgreSQL Initialization Script for ZSXQ_TOKEN
set -e

echo "=== PostgreSQL Database Initialization (Docker) ==="
echo "Date: $(date)"
echo ""

# Configuration
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-zsxq-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
  echo "❌ ERROR: PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
  exit 1
fi

echo "✅ PostgreSQL container found: ${POSTGRES_CONTAINER}"

# Function to execute SQL via docker exec
exec_sql() {
  docker exec -i "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}" "$@"
}

# Check PostgreSQL version
PG_VERSION=$(exec_sql -t -c "SHOW server_version;" | grep -oP '\d+\.\d+' | head -1)
echo "✅ PostgreSQL version: ${PG_VERSION}"

# Check for conflicts
echo ""
echo "🔍 Checking for existing roles/databases..."
CONFLICT_ROLES=$(exec_sql -t -c "SELECT rolname FROM pg_roles WHERE rolname LIKE 'zsxq_%';" | xargs)
CONFLICT_DBS=$(exec_sql -t -c "SELECT datname FROM pg_database WHERE datname IN ('new_api', 'opc_core', 'super_canvas');" | xargs)

if [ -n "$CONFLICT_ROLES" ]; then
  echo "⚠️  Found existing roles: $CONFLICT_ROLES"
  echo "These will be dropped and recreated."
fi

if [ -n "$CONFLICT_DBS" ]; then
  echo "⚠️  Found existing databases: $CONFLICT_DBS"
  echo "These will be dropped and recreated."
fi

# Generate secure passwords (40 characters)
echo ""
echo "🔐 Generating secure passwords..."
NEW_API_MIGRATION_PWD=$(openssl rand -base64 30 | tr -d '\n')
NEW_API_RUNTIME_PWD=$(openssl rand -base64 30 | tr -d '\n')
OPC_MIGRATION_PWD=$(openssl rand -base64 30 | tr -d '\n')
OPC_RUNTIME_PWD=$(openssl rand -base64 30 | tr -d '\n')
CANVAS_MIGRATION_PWD=$(openssl rand -base64 30 | tr -d '\n')
CANVAS_RUNTIME_PWD=$(openssl rand -base64 30 | tr -d '\n')

# Create initialization SQL
cat > /tmp/init.sql << 'EOFSQL'
-- Drop existing databases
DROP DATABASE IF EXISTS super_canvas;
DROP DATABASE IF EXISTS opc_core;
DROP DATABASE IF EXISTS new_api;

-- Drop existing roles
DROP ROLE IF EXISTS zsxq_super_canvas_runtime;
DROP ROLE IF EXISTS zsxq_super_canvas_migration;
DROP ROLE IF EXISTS zsxq_super_canvas_owner;
DROP ROLE IF EXISTS zsxq_opc_core_runtime;
DROP ROLE IF EXISTS zsxq_opc_core_migration;
DROP ROLE IF EXISTS zsxq_opc_core_owner;
DROP ROLE IF EXISTS zsxq_new_api_runtime;
DROP ROLE IF EXISTS zsxq_new_api_migration;
DROP ROLE IF EXISTS zsxq_new_api_owner;

-- Create New API roles
CREATE ROLE zsxq_new_api_owner NOLOGIN;
CREATE ROLE zsxq_new_api_migration LOGIN NOINHERIT PASSWORD 'NEW_API_MIGRATION_PWD_PLACEHOLDER';
CREATE ROLE zsxq_new_api_runtime LOGIN PASSWORD 'NEW_API_RUNTIME_PWD_PLACEHOLDER';
GRANT zsxq_new_api_owner TO zsxq_new_api_migration;

-- Create OPC Core roles
CREATE ROLE zsxq_opc_core_owner NOLOGIN;
CREATE ROLE zsxq_opc_core_migration LOGIN NOINHERIT PASSWORD 'OPC_MIGRATION_PWD_PLACEHOLDER';
CREATE ROLE zsxq_opc_core_runtime LOGIN PASSWORD 'OPC_RUNTIME_PWD_PLACEHOLDER';
GRANT zsxq_opc_core_owner TO zsxq_opc_core_migration;

-- Create Super Canvas roles
CREATE ROLE zsxq_super_canvas_owner NOLOGIN;
CREATE ROLE zsxq_super_canvas_migration LOGIN NOINHERIT PASSWORD 'CANVAS_MIGRATION_PWD_PLACEHOLDER';
CREATE ROLE zsxq_super_canvas_runtime LOGIN PASSWORD 'CANVAS_RUNTIME_PWD_PLACEHOLDER';
GRANT zsxq_super_canvas_owner TO zsxq_super_canvas_migration;

-- Create databases
CREATE DATABASE new_api OWNER zsxq_new_api_owner ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
CREATE DATABASE opc_core OWNER zsxq_opc_core_owner ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
CREATE DATABASE super_canvas OWNER zsxq_super_canvas_owner ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
EOFSQL

# Replace password placeholders (escape / characters for sed)
NEW_API_MIGRATION_PWD_ESCAPED=$(echo "${NEW_API_MIGRATION_PWD}" | sed 's/[\/&]/\\&/g')
NEW_API_RUNTIME_PWD_ESCAPED=$(echo "${NEW_API_RUNTIME_PWD}" | sed 's/[\/&]/\\&/g')
OPC_MIGRATION_PWD_ESCAPED=$(echo "${OPC_MIGRATION_PWD}" | sed 's/[\/&]/\\&/g')
OPC_RUNTIME_PWD_ESCAPED=$(echo "${OPC_RUNTIME_PWD}" | sed 's/[\/&]/\\&/g')
CANVAS_MIGRATION_PWD_ESCAPED=$(echo "${CANVAS_MIGRATION_PWD}" | sed 's/[\/&]/\\&/g')
CANVAS_RUNTIME_PWD_ESCAPED=$(echo "${CANVAS_RUNTIME_PWD}" | sed 's/[\/&]/\\&/g')

sed -i "s/NEW_API_MIGRATION_PWD_PLACEHOLDER/${NEW_API_MIGRATION_PWD_ESCAPED}/g" /tmp/init.sql
sed -i "s/NEW_API_RUNTIME_PWD_PLACEHOLDER/${NEW_API_RUNTIME_PWD_ESCAPED}/g" /tmp/init.sql
sed -i "s/OPC_MIGRATION_PWD_PLACEHOLDER/${OPC_MIGRATION_PWD_ESCAPED}/g" /tmp/init.sql
sed -i "s/OPC_RUNTIME_PWD_PLACEHOLDER/${OPC_RUNTIME_PWD_ESCAPED}/g" /tmp/init.sql
sed -i "s/CANVAS_MIGRATION_PWD_PLACEHOLDER/${CANVAS_MIGRATION_PWD_ESCAPED}/g" /tmp/init.sql
sed -i "s/CANVAS_RUNTIME_PWD_PLACEHOLDER/${CANVAS_RUNTIME_PWD_ESCAPED}/g" /tmp/init.sql

echo ""
echo "🔧 Creating roles and databases..."
cat /tmp/init.sql | docker exec -i "${POSTGRES_CONTAINER}" psql -U "${POSTGRES_USER}"

# Clean up temp file
rm -f /tmp/init.sql

echo ""
echo "=== Initialization Complete ==="
echo ""
echo "# Copy these to .env.local on Lisa:"
echo ""
echo "NEW_API_DB_HOST=postgres"
echo "NEW_API_DB_PORT=5432"
echo "NEW_API_DB_NAME=new_api"
echo "NEW_API_DB_USER=zsxq_new_api_runtime"
echo "NEW_API_DB_PASSWORD=${NEW_API_RUNTIME_PWD}"
echo ""
echo "OPC_DB_HOST=postgres"
echo "OPC_DB_PORT=5432"
echo "OPC_DB_NAME=opc_core"
echo "OPC_DB_USER=zsxq_opc_core_runtime"
echo "OPC_DB_PASSWORD=${OPC_RUNTIME_PWD}"
echo ""
echo "CANVAS_DB_HOST=postgres"
echo "CANVAS_DB_PORT=5432"
echo "CANVAS_DB_NAME=super_canvas"
echo "CANVAS_DB_USER=zsxq_super_canvas_runtime"
echo "CANVAS_DB_PASSWORD=${CANVAS_RUNTIME_PWD}"
echo ""
echo "✅ Database is ready."
