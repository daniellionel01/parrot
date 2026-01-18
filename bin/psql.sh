#!/bin/bash
CONTAINER_NAME="parrot-psql"

if [ -n "$(podman ps -q -f name=^${CONTAINER_NAME}$)" ]; then
  echo "Container '${CONTAINER_NAME}' is already running."
else
  if [ -n "$(podman ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    echo "Container '${CONTAINER_NAME}' exists but is stopped. Removing it..."
    podman rm -f ${CONTAINER_NAME}
  fi
  echo "Container '${CONTAINER_NAME}' not found. Starting it..."
  # postgresql://daniel:parrot@127.0.0.1:5432/parrot
  podman run \
    --rm -d \
    --name ${CONTAINER_NAME} \
    -e POSTGRES_USER=daniel \
    -e POSTGRES_PASSWORD=parrot \
    -e POSTGRES_DB=parrot \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -p 5432:5432 \
    -v /var/lib/db-parrot:/var/lib/postgresql/data/pgdata \
    postgres:17
  echo "Container '${CONTAINER_NAME}' started successfully."
fi
