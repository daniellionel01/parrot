#!/bin/bash

# mysql://root:daniel@127.0.0.1:3309/parrot
docker run \
  --rm -d \
  --name parrot-mysql \
  -e="MYSQL_ROOT_PASSWORD=daniel" \
  -e="MYSQL_DATABASE=parrot" \
  -p 3309:3306 \
  -v=mysql_data:/var/lib/mysql \
  mysql:8.0.30 \
  --default-authentication-plugin=caching_sha2_password \
  --max_connections=10000
