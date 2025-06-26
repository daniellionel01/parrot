#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT="${SCRIPT_DIR}/.."

SCHEMA_FILE="${PROJECT_ROOT}/priv/schema.sql"
SEED_FILE="${PROJECT_ROOT}/priv/seed.sql"

if [ -z "${DATABASE_URL}" ]; then
  echo "Error: DATABASE_URL environment variable is not set."
  exit 1
fi

# Handle host resolution for Docker environments
if [[ "$DATABASE_URL" == *"@postgres:"* ]]; then
  # We're in Docker, wait for PostgreSQL to be ready
  MAX_ATTEMPTS=30
  ATTEMPT=1
  
  echo "Waiting for PostgreSQL to be ready..."
  until PGPASSWORD=parrot psql -h postgres -U daniel -d postgres -c "SELECT 1;" &>/dev/null; do
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: PostgreSQL not ready yet..."
    sleep 2
    
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
      echo "Error: PostgreSQL did not become ready in time."
      exit 1
    fi
  done
  
  echo "PostgreSQL is ready!"
fi

if [ ! -f "${SCHEMA_FILE}" ]; then
  echo "Error: Schema file not found at: ${SCHEMA_FILE}"
  exit 1
fi

if [ ! -f "${SEED_FILE}" ]; then
  echo "Error: Seed file not found at: ${SEED_FILE}"
  exit 1
fi

echo "--> Parsing DATABASE_URL..."

URL_BODY="${DATABASE_URL#postgresql://}"

CREDENTIALS="${URL_BODY%@*}"
HOST_AND_DB="${URL_BODY#*@}"

DB_USER="${CREDENTIALS%:*}"
DB_PASS="${CREDENTIALS#*:}"

HOST_WITH_PORT="${HOST_AND_DB%/*}"
DB_HOST="${HOST_WITH_PORT%:*}"
DB_NAME="${HOST_AND_DB#*/}"
DB_PORT="${HOST_WITH_PORT#*:}"

if [ -z "${DB_PORT}" ]; then
  DB_PORT="5432"
fi

echo "--> Resetting database '${DB_NAME}' on '${DB_HOST_WITH_PORT}'..."

PGPASSWORD="${DB_PASS}" dropdb --if-exists --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USER}" "${DB_NAME}"
PGPASSWORD="${DB_PASS}" createdb --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USER}" "${DB_NAME}"

PGPASSWORD="${DB_PASS}" psql --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USER}" --dbname="${DB_NAME}" --file="${SCHEMA_FILE}"
PGPASSWORD="${DB_PASS}" psql --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USER}" --dbname="${DB_NAME}" --file="${SEED_FILE}"

echo "--> Database reset complete."
