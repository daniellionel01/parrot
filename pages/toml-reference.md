# TOML reference

Parrot is configured in `gleam.toml` under `[tools.parrot]`. Command line flags take precedence.

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

| Key | Flag | Default | |
| --- | --- | --- | --- |
| `output` | `--output` | `src/<project>/sql.gleam` | generated module |
| `env` | `-e`, `--env-var` | `DATABASE_URL` | environment variable with the connection string |
| `engine` | `--engine` | detected from the connection string | `postgresql`, `mysql` or `sqlite`. Required with `schema` and no connection string |

## `tools.parrot.sqlc`

| Key | Flag | Default | |
| --- | --- | --- | --- |
| `bin` | `--sqlc` | downloaded by parrot | `"system"` (`sqlc` in `PATH`) or a path. A different sqlc version only prints a warning |
| `schema` | `--schema` | fetched from the database | schema or migration files, no database needed ([sqlc docs](https://docs.sqlc.dev/en/stable/howto/ddl.html#handling-sql-migrations)) |

`--sqlite <path>` sets a sqlite database file directly.
