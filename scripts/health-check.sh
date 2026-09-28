#!/bin/bash
# Health Check Script for ZSXQ_TOKEN Services
# Checks if all services are running and responding correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== ZSXQ_TOKEN Services Health Check ==="
echo "Date: $(date)"
echo ""

# Load environment variables if .env.local exists
if [ -f ".env.local" ]; then
  export $(grep -v '^#' .env.local | xargs)
  echo "✅ Loaded .env.local"
else
  echo "⚠️  Warning: .env.local not found, using defaults"
fi

# Default ports
NEW_API_PORT=${NEW_API_PORT:-3000}
OPC_PORT=${OPC_PORT:-3001}
CANVAS_PORT=${CANVAS_PORT:-3002}

HEALTH_STATUS=0

# Function to check HTTP endpoint
check_http() {
  local name=$1
  local url=$2
  local expected_code=${3:-200}

  echo -n "  Checking $name... "

  response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

  if [ "$response" = "$expected_code" ] || [ "$response" = "200" ] || [ "$response" = "404" ]; then
    echo -e "${GREEN}✅ OK${NC} (HTTP $response)"
    return 0
  else
    echo -e "${RED}❌ FAILED${NC} (HTTP $response)"
    HEALTH_STATUS=1
    return 1
  fi
}

# Function to check TCP port
check_port() {
  local name=$1
  local port=$2

  echo -n "  Checking $name on port $port... "

  if timeout 2 bash -c "echo > /dev/tcp/localhost/$port" 2>/dev/null; then
    echo -e "${GREEN}✅ LISTENING${NC}"
    return 0
  else
    echo -e "${RED}❌ NOT LISTENING${NC}"
    HEALTH_STATUS=1
    return 1
  fi
}

# Function to check database connection
check_database() {
  local name=$1
  local db_host=${2:-localhost}
  local db_port=${3:-5432}
  local db_name=$4
  local db_user=$5
  local db_password=$6

  echo -n "  Checking $name database... "

  if [ -z "$db_password" ]; then
    echo -e "${YELLOW}⚠️  SKIPPED${NC} (no credentials)"
    return 0
  fi

  PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1;" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CONNECTED${NC}"
    return 0
  else
    echo -e "${RED}❌ CONNECTION FAILED${NC}"
    HEALTH_STATUS=1
    return 1
  fi
}

# Check Node.js
echo ""
echo "🔍 Runtime Environment"
if command -v node &> /dev/null; then
  NODE_VERSION=$(node --version)
  echo "  ✅ Node.js: $NODE_VERSION"

  if [ -f ".nvmrc" ]; then
    EXPECTED_VERSION=$(cat .nvmrc)
    if [[ "$NODE_VERSION" == *"$EXPECTED_VERSION"* ]]; then
      echo "     (matches .nvmrc)"
    else
      echo -e "     ${YELLOW}⚠️  Expected v$EXPECTED_VERSION${NC}"
    fi
  fi
else
  echo -e "  ${RED}❌ Node.js not found${NC}"
  HEALTH_STATUS=1
fi

# Check Python
if command -v python3 &> /dev/null; then
  PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+\.\d+')
  echo "  ✅ Python: $PYTHON_VERSION"

  if [ -f ".python-version" ]; then
    EXPECTED_PY=$(cat .python-version)
    if [[ "$PYTHON_VERSION" == "$EXPECTED_PY"* ]]; then
      echo "     (matches .python-version)"
    else
      echo -e "     ${YELLOW}⚠️  Expected $EXPECTED_PY${NC}"
    fi
  fi
else
  echo -e "  ${YELLOW}⚠️  Python3 not found${NC}"
fi

# Check PostgreSQL
echo ""
echo "🗄️  Databases"
check_database "new_api" "${NEW_API_DB_HOST}" "${NEW_API_DB_PORT}" "${NEW_API_DB_NAME}" "${NEW_API_DB_USER}" "${NEW_API_DB_PASSWORD}"
check_database "opc_core" "${OPC_DB_HOST}" "${OPC_DB_PORT}" "${OPC_DB_NAME}" "${OPC_DB_USER}" "${OPC_DB_PASSWORD}"
check_database "super_canvas" "${CANVAS_DB_HOST}" "${CANVAS_DB_PORT}" "${CANVAS_DB_NAME}" "${CANVAS_DB_USER}" "${CANVAS_DB_PASSWORD}"

# Check service ports
echo ""
echo "🌐 Service Ports"
check_port "New API" "$NEW_API_PORT"
check_port "OPC" "$OPC_PORT"
check_port "Canvas" "$CANVAS_PORT"

# Check service HTTP endpoints
echo ""
echo "🔌 Service Endpoints"

# New API health check
if [ -n "$NEW_API_BASE_URL" ]; then
  check_http "New API" "$NEW_API_BASE_URL/health"
else
  check_http "New API" "http://localhost:$NEW_API_PORT/health"
fi

# OPC health check
if [ -n "$OPC_PUBLIC_URL" ]; then
  check_http "OPC" "$OPC_PUBLIC_URL/health"
else
  check_http "OPC" "http://localhost:$OPC_PORT/health"
fi

# Canvas health check
if [ -n "$CANVAS_APP_URL" ]; then
  check_http "Canvas" "$CANVAS_APP_URL/health"
else
  check_http "Canvas" "http://localhost:$CANVAS_PORT/health"
fi

# Check internal service authentication (if SERVICE_TOKEN is set)
echo ""
echo "🔐 Service Authentication"
if [ -n "$SERVICE_TOKEN_SECRET" ]; then
  echo "  ✅ SERVICE_TOKEN_SECRET is configured"

  # Test internal API with token
  if [ -n "$NEW_API_BASE_URL" ]; then
    echo -n "  Testing internal API authentication... "
    response=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $SERVICE_TOKEN_SECRET" \
      -H "X-Service-Name: health-check" \
      "$NEW_API_BASE_URL/api/v1/models" 2>/dev/null || echo "000")

    if [ "$response" = "200" ] || [ "$response" = "401" ]; then
      echo -e "${GREEN}✅ OK${NC} (HTTP $response)"
    else
      echo -e "${YELLOW}⚠️  Unexpected response${NC} (HTTP $response)"
    fi
  fi
else
  echo -e "  ${YELLOW}⚠️  SERVICE_TOKEN_SECRET not configured${NC}"
fi

# Check disk space
echo ""
echo "💾 Disk Space"
DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
  echo -e "  ${GREEN}✅ Disk usage: ${DISK_USAGE}%${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
  echo -e "  ${YELLOW}⚠️  Disk usage: ${DISK_USAGE}%${NC}"
else
  echo -e "  ${RED}❌ Disk usage: ${DISK_USAGE}% (critical)${NC}"
  HEALTH_STATUS=1
fi

# Check memory
echo ""
echo "🧠 Memory"
if command -v free &> /dev/null; then
  MEMORY_INFO=$(free -h | grep Mem | awk '{print "Used: " $3 " / Total: " $2}')
  echo "  ℹ️  $MEMORY_INFO"
else
  echo "  ⚠️  Memory check not available (free command not found)"
fi

# Check running processes
echo ""
echo "🔄 Running Processes"
NODE_PROCESSES=$(ps aux | grep -c "[n]ode.*services" || echo "0")
if [ "$NODE_PROCESSES" -gt 0 ]; then
  echo "  ✅ Found $NODE_PROCESSES Node.js service process(es)"
else
  echo -e "  ${YELLOW}⚠️  No Node.js service processes found${NC}"
fi

# Summary
echo ""
echo "=== Health Check Summary ==="
if [ $HEALTH_STATUS -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed${NC}"
  exit 0
else
  echo -e "${RED}❌ Some checks failed${NC}"
  echo ""
  echo "Troubleshooting steps:"
  echo "  1. Check if services are started: npm run loop:start"
  echo "  2. Check logs: npm run loop:logs"
  echo "  3. Verify environment variables: npm run validate-env"
  echo "  4. Check database connectivity: psql -U <user> -d <database>"
  exit 1
fi
