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

if [ ! -f "${SCHEMA_FILE}" ]; then
  echo "Error: Schema file not found at: ${SCHEMA_FILE}"
  exit 1
fi

if [ ! -f "${SEED_FILE}" ]; then
  echo "Error: Seed file not found at: ${SEED_FILE}"
  exit 1
fi

echo "--> Parsing DATABASE_URL..."

URL_BODY="${DATABASE_URL#mysql://}"

CREDENTIALS="${URL_BODY%@*}"
HOST_AND_DB="${URL_BODY#*@}"

DB_USER="${CREDENTIALS%:*}"
DB_PASS="${CREDENTIALS#*:}"

HOST_WITH_PORT="${HOST_AND_DB%/*}"
DB_HOST="${HOST_WITH_PORT%:*}"
DB_NAME="${HOST_AND_DB#*/}"
DB_PORT="${HOST_WITH_PORT#*:}"

if [ "${DB_HOST}" == "${DB_PORT}" ]; then
  DB_PORT="3306"
fi

export MYSQL_PWD="${DB_PASS}"

echo "--> Resetting database '${DB_NAME}' on '${DB_HOST_WITH_PORT}'..."

mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -D "${DB_NAME}" < "${SCHEMA_FILE}"
mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -D "${DB_NAME}" < "${SEED_FILE}"

echo "--> Database reset complete."
