#!/bin/bash

CONTAINER_NAME="parrot-mysql"

if [ -n "$(podman ps -q -f name=^${CONTAINER_NAME}$)" ]; then
  echo "Container '${CONTAINER_NAME}' is already running."
else
  if [ -n "$(podman ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    echo "Container '${CONTAINER_NAME}' exists but is stopped. Removing it..."
    podman rm -f ${CONTAINER_NAME}
  fi
  echo "Container '${CONTAINER_NAME}' not found. Starting it..."
  # mysql://root:daniel@127.0.0.1:3309/parrot
  podman run \
    --rm -d \
    --name ${CONTAINER_NAME} \
    -e MYSQL_ROOT_PASSWORD=daniel \
    -e MYSQL_DATABASE=parrot \
    -p 3309:3306 \
    -v mysql_data:/var/lib/mysql \
    mysql:8.0.30 \
    --bind-address=0.0.0.0 \
    --default-authentication-plugin=caching_sha2_password \
    --max_connections=10000
  echo "Container '${CONTAINER_NAME}' started successfully. Waiting for MySQL to be ready..."
  for i in {1..30}; do
    if mysql -h 127.0.0.1 -P 3309 -u root -pdaniel -e "SELECT 1" > /dev/null 2>&1; then
      echo "MySQL is ready!"
      break
    fi
    echo "Waiting for MySQL... ($i/30)"
    sleep 1
  done
fi
