#!/bin/bash
set -e

# Default command is "run"
CMD=${1:-run}

if [ "$CMD" = "run" ]; then
  # Run the normal application
  echo "Starting the application..."
  /app/build/erlang-shipment/entrypoint.sh run
elif [ "$CMD" = "test" ]; then
  # Run the integration tests
  echo "Running integration tests..."
  /app/run-tests.sh
else
  # Run any other command passed to the entrypoint
  exec "$@"
fi