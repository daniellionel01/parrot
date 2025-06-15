import envoy
import given
import parrot/internal/errors

pub const usage = "
  🦜 Parrot - type-safe SQL in gleam for sqlite, postgresql & mysql

  USAGE:
    gleam run -m parrot [OPTIONS]
    gleam run -m parrot help

  DESCRIPTION:
    This tool generates type-safe Gleam code from your raw SQL queries.
    It connects to your database to introspect schemas and validate queries,
    then generates Gleam functions that you can use in your application.

    By default, it automatically detects your database driver (PostgreSQL,
    MySQL, or SQLite) by reading the DATABASE_URL environment variable.

  OPTIONS:
    --sqlite <file_path>
      Directly specify the path to a SQLite database file. When this
      option is used, it bypasses the DATABASE_URL environment
      variable entirely.

    -e, --env-var <VAR_NAME>
      Specify the name of an alternative environment variable to use
      for the database connection URL.
      Defaults to 'DATABASE_URL'.

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

    # 2. Using SQlite: directly point to a database file.
    $ gleam run -m parrot --sqlite ./priv/app.db

    # 3. Different environment variable
    $ export STAGING_DB_URL=\"mysql://staging:pass@remote/db\"
    $ gleam run -m parrot --env-var STAGING_DB_URL

    # 4. Get help
    $ gleam run -m parrot help
"

pub type Command {
  Usage
  Generate(engine: Engine, db: String)
}

pub type Engine {
  SQlite
  MySQL
  PostgreSQL
}

pub fn engine_from_env(str: String) {
  case str {
    "postgres" <> _ -> Ok(PostgreSQL)
    "mysql" <> _ -> Ok(MySQL)
    "file" <> _ -> Ok(SQlite)
    _ -> {
      Error(errors.UnknownEngine(str))
    }
  }
}

pub fn parse_env(env: String) -> Result(#(Engine, String), String) {
  let env_var = envoy.get(env)
  use env_var <- given.ok(env_var, else_return: fn(_) {
    Error("Environment Variable \"DATABASE_URL\" is empty!")
  })

  let engine = engine_from_env(env_var)
  use engine <- given.ok(engine, else_return: fn(_) {
    Error(
      "\"DATABASE_URL\" does not match any of the supported formats (MySQL, PostgreSQL, SQlite)",
    )
  })

  Ok(#(engine, env_var))
}
