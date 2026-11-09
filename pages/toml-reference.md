# TOML reference

Parrot is configured in `gleam.toml` under `[tools.parrot]`. Command line flags take precedence.

Relative paths, including sqlite paths in connection strings, are relative to the project's root.

`--sqlite <path>` has no `gleam.toml` key, it sets a sqlite database file directly.

```toml
[tools.parrot]
output = "src/app/sql.gleam"
env = "DATABASE_URL"
engine = "postgresql"

[tools.parrot.sqlc]
bin = "system"
schema = "priv/migrations"
```

## `tools.parrot`

### `output`

Generated module.

- Flag: `--output`
- Default: `src/<project>/sql.gleam`

### `env`

Environment variable with the connection string.

- Flag: `-e`, `--env-var`
- Default: `DATABASE_URL`

### `engine`

`postgresql`, `mysql` or `sqlite`. Required with `schema` and no connection string.

- Flag: `--engine`
- Default: detected from the connection string

## `tools.parrot.sqlc`

### `bin`

`"system"` (`sqlc` in `PATH`) or a path. A different sqlc version only prints a warning.

- Flag: `--sqlc`
- Default: downloaded by parrot

### `schema`

Schema or migration files, no database needed ([sqlc docs](https://docs.sqlc.dev/en/stable/howto/ddl.html#handling-sql-migrations)).

- Flag: `--schema`
- Default: fetched from the database
