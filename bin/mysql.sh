#!/bin/bash

CONTAINER_NAME="parrot-mysql"

if [ -n "$(docker ps -q -f name=^${CONTAINER_NAME}$)" ]; then
  echo "Container '${CONTAINER_NAME}' is already running."
else
  echo "Container '${CONTAINER_NAME}' not found. Starting it..."
  # mysql://root:daniel@127.0.0.1:3309/parrot
  docker run \
    --rm -d \
    --name ${CONTAINER_NAME} \
    -e="MYSQL_ROOT_PASSWORD=daniel" \
    -e="MYSQL_DATABASE=parrot" \
    -p 3309:3306 \
    -v=mysql_data:/var/lib/mysql \
    mysql:8.0.30 \
    --default-authentication-plugin=caching_sha2_password \
    --max_connections=10000
  echo "Container '${CONTAINER_NAME}' started successfully."
fi
