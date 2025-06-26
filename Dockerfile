FROM erlang:27.1.1.0-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base gcc musl-dev

COPY --from=ghcr.io/gleam-lang/gleam:v1.11.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment

FROM erlang:27.1.1.0-alpine

# Install build dependencies and database clients
RUN apk add --no-cache \
  sqlite \
  mysql-client \
  postgresql-client \
  bash \
  curl \
  make \
  git

# Copy gleam binary from build stage
COPY --from=build /bin/gleam /bin/gleam

# Install just command runner
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp

# Copy the entire app directory including integration tests
COPY --from=build /app /app
WORKDIR /app

# Create a script to run integration tests with configurable database URLs
RUN echo '#!/bin/bash' > /app/run-tests.sh && \
    echo 'set -e' >> /app/run-tests.sh && \
    echo 'cd /app' >> /app/run-tests.sh && \
    echo 'if [ -n "$MYSQL_DATABASE_URL" ]; then' >> /app/run-tests.sh && \
    echo '  export DATABASE_URL="$MYSQL_DATABASE_URL"' >> /app/run-tests.sh && \
    echo '  cd integration_test/mysql && gleam run -m parrot && cd -' >> /app/run-tests.sh && \
    echo 'fi' >> /app/run-tests.sh && \
    echo 'if [ -n "$POSTGRES_DATABASE_URL" ]; then' >> /app/run-tests.sh && \
    echo '  export DATABASE_URL="$POSTGRES_DATABASE_URL"' >> /app/run-tests.sh && \
    echo '  cd integration_test/psql && gleam run -m parrot && cd -' >> /app/run-tests.sh && \
    echo 'fi' >> /app/run-tests.sh && \
    echo 'cd integration_test/sqlite && gleam run -m parrot' >> /app/run-tests.sh && \
    chmod +x /app/run-tests.sh

ENTRYPOINT ["/bin/sh"]
CMD ["/app/entrypoint.sh", "run"]
