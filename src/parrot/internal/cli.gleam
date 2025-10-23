import envoy
import gleam/result
import parrot/internal/errors
import parrot/internal/sqlc

pub const usage = "
  🦜 Parrot - type-safe SQL in gleam for sqlite, postgresql & mysql

  USAGE:
    gleam run -m parrot -- [OPTIONS]
    gleam run -m parrot help

  DESCRIPTION:
    This tool generates type-safe Gleam code from your raw SQL queries.
    It connects to your database to introspect schemas and validate queries,
    then generates Gleam functions that you can use in your application.

    By default, it automatically detects your database driver (PostgreSQL,
    MySQL, or SQLite) by reading the DATABASE_URL environment variable.

  OPTIONS:
    --sqlite=<FILE_PATH>
      Directly specify the path to a SQLite database file. When this
      option is used, it bypasses the DATABASE_URL environment
      variable entirely.

    --env-var=<VAR_NAME>
      Specify the name of an alternative environment variable to use
      for the database connection URL.
      Defaults to 'DATABASE_URL'.

    --sqlc=<ABSOLUTE_FILE_PATH>
      Specify the absolute path to an `sqlc` binary
      Defaults to downloading and using `build/.parrot/sqlc`

  DATABASE_URL:
    Parrot automatically detects the driver from the URL scheme.

    Formats:
    - PostgreSQL: postgres://user:password@host:port/dbname
    - MySQL:      mysql://user:password@host:port/dbname
    - SQLite:     file:/path/to/your/database.db

  EXAMPLES:
    # 1. The default: run with a DATABASE_URL environment variable set.
    $ export DATABASE_URL=\"postgres://user:pass@localhost/mydb\"
    $ gleam run -m parrot

    # 2. Using Sqlite: directly point to a database file.
    $ gleam run -m parrot -- --sqlite=./priv/app.db

    # 3. Different environment variable
    $ export STAGING_DB_URL=\"mysql://staging:pass@remote/db\"
    $ gleam run -m parrot -- --env-var=STAGING_DB_URL

    # 4. Get help
    $ gleam run -m parrot help
"

pub type Command {
  Usage
  Generate(
    engine: sqlc.Engine,
    db: String,
  )
}

pub fn engine_from_env(str: String) {
  case str {
    "postgres" <> _ -> Ok(sqlc.PostgreSQL)
    "mysql" <> _ -> Ok(sqlc.MySQL)
    "file" | "sqlite" <> _ -> Ok(sqlc.SQLite)
    _ -> Error(errors.UnknownEngine(str))
  }
}

pub fn parse_env(env: String) -> Result(#(sqlc.Engine, String), String) {
  let env_result = envoy.get(env)
  use env_var <- result.try(result.replace_error(
    env_result,
    "Environment Variable \"" <> env <> "\" is empty!",
  ))

  let engine_result = engine_from_env(env_var)
  use engine <- result.try(result.replace_error(
    engine_result,
    "\""
      <> env
      <> "\" does not match any of the supported formats (MySQL, PostgreSQL, SQLite)",
  ))

  Ok(#(engine, env_var))
}
