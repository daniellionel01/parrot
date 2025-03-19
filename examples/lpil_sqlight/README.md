# lpil_sqlight

This is an example project showing off the usage of [parrot](https://github.com/daniellionel01/parrot) with [lpil/sqlight](https://github.com/lpil/sqlight)

## Development

```sh
sqlc generate --file sql/sqlc.yaml # Generate the codegen.json
gleam run -m lpil_sqlight/parrot   # Generate type-safe sql
gleam run                          # Run the project
```
