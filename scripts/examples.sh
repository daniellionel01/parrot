#!/bin/bash

gleam build

cd examples/lpil_sqlight
sqlc generate --file sql/sqlc.yaml
gleam run -m lpil_sqlight/parrot
gleam run

cd ../lpil_pog
