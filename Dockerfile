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
  git \
  build-base \
  gcc \
  musl-dev

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

ENTRYPOINT ["/bin/sh"]
CMD ["/app/entrypoint.sh", "run"]
