import gleam/list
import gleam/option.{Some}
import parrot/error
import parrot/internal/cli.{Flags, no_flags}
import parrot/internal/config.{Config}
import parrot/internal/database
import tom

const url = "postgresql://user:pass@localhost/app"

fn resolve(flags: cli.Flags, toml: String, env: List(#(String, String))) {
  let assert Ok(toml) = tom.parse("name = \"app\"\n" <> toml)
  config.resolve(flags, toml, list.key_find(env, _))
}

pub fn parse_test() {
  assert cli.parse([
      "--sqlite", "app.db", "-e", "URL", "--output", "src/db.gleam", "--schema",
      "priv/schema.sql", "--engine", "mysql", "--sqlc", "system",
    ])
    == Ok(
      cli.Generate(Flags(
        sqlite: Some("app.db"),
        env: Some("URL"),
        output: Some("src/db.gleam"),
        schema: Some("priv/schema.sql"),
        engine: Some("mysql"),
        sqlc: Some("system"),
      )),
    )
  assert cli.parse(["--env-var", "URL"])
    == Ok(cli.Generate(Flags(..no_flags, env: Some("URL"))))
}

pub fn parse_help_test() {
  assert cli.parse(["help"]) == Ok(cli.Help)
  assert cli.parse(["--sqlite", "app.db", "-h"]) == Ok(cli.Help)
}

pub fn parse_invalid_test() {
  let assert Error(error.InvalidArgument(_)) = cli.parse(["--wibble"])
  let assert Error(error.InvalidArgument(_)) = cli.parse(["generate"])
}

pub fn defaults_test() {
  assert resolve(no_flags, "", [#("DATABASE_URL", url)])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: database.PostgreSQL,
      schema: config.FromDatabase(url),
      sqlc: config.Managed,
    ))
}

pub fn toml_test() {
  let toml =
    "
[tools.parrot]
output = \"src/app/db.gleam\"
env = \"APP_DB\"

[tools.parrot.sqlc]
bin = \"system\"
"
  assert resolve(no_flags, toml, [#("APP_DB", url)])
    == Ok(Config(
      output: "src/app/db.gleam",
      engine: database.PostgreSQL,
      schema: config.FromDatabase(url),
      sqlc: config.System,
    ))
}

pub fn flags_override_toml_test() {
  let toml = "[tools.parrot]\noutput = \"src/app/db.gleam\"\n"
  let flags = Flags(..no_flags, output: Some("src/other.gleam"))
  let assert Ok(Config(output: "src/other.gleam", ..)) =
    resolve(flags, toml, [#("DATABASE_URL", url)])
}

pub fn sqlite_test() {
  let flags = Flags(..no_flags, sqlite: Some("app.db"))
  let assert Ok(Config(
    engine: database.SQLite,
    schema: config.FromDatabase("sqlite:app.db"),
    ..,
  )) = resolve(flags, "", [])
}

pub fn schema_without_database_test() {
  let flags =
    Flags(..no_flags, schema: Some("priv/schema.sql"), engine: Some("mysql"))
  let assert Ok(Config(
    engine: database.MySQL,
    schema: config.FromFiles("priv/schema.sql"),
    ..,
  )) = resolve(flags, "", [])

  let flags = Flags(..no_flags, schema: Some("priv/schema.sql"))
  assert resolve(flags, "", []) == Error(error.MissingEngine)
}

pub fn sqlite_overrides_env_test() {
  let flags = Flags(..no_flags, sqlite: Some("app.db"))
  let assert Ok(Config(engine: database.SQLite, ..)) =
    resolve(flags, "", [#("DATABASE_URL", url)])
}

pub fn errors_test() {
  assert resolve(no_flags, "", [])
    == Error(error.EnvironmentVariableEmpty("DATABASE_URL"))
  assert resolve(no_flags, "[tools.parrot]\nenv = \"APP_DB\"\n", [
      #("APP_DB", ""),
    ])
    == Error(error.EnvironmentVariableEmpty("APP_DB"))
  assert resolve(no_flags, "", [#("DATABASE_URL", "wibble://db")])
    == Error(error.MissingEngine)
  assert resolve(Flags(..no_flags, engine: Some("oracle")), "", [
      #("DATABASE_URL", url),
    ])
    == Error(error.UnknownEngine("oracle"))
  let assert Error(error.GleamTomlError(_)) =
    resolve(no_flags, "[tools.parrot]\noutput = 1\n", [#("DATABASE_URL", url)])
}
