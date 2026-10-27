import gleam/list
import gleam/option.{Some}
import parrot/error
import parrot/internal/cli.{Flags, no_flags}
import parrot/internal/config.{Config}
import parrot/internal/sqlc
import tom

fn resolve(flags: cli.Flags, toml: String, env: List(#(String, String))) {
  let assert Ok(toml) = tom.parse("name = \"app\"\n" <> toml)
  config.resolve(flags, toml, list.key_find(env, _))
}

const postgres_url = "postgresql://user:pass@localhost/app"

// === CLI ==================================================================

pub fn parse_no_arguments_test() {
  assert cli.parse([]) == Ok(cli.Generate(no_flags))
}

pub fn parse_help_test() {
  assert cli.parse(["help"]) == Ok(cli.Help)
  assert cli.parse(["--help"]) == Ok(cli.Help)
}

pub fn parse_flags_test() {
  assert cli.parse([
      "--sqlite", "app.db", "-e", "URL", "--output", "src/db.gleam", "--schema",
      "priv/migrations", "--engine", "sqlite", "--sqlc", "system",
    ])
    == Ok(
      cli.Generate(Flags(
        sqlite: Some("app.db"),
        env: Some("URL"),
        output: Some("src/db.gleam"),
        schema: Some("priv/migrations"),
        engine: Some("sqlite"),
        sqlc: Some("system"),
      )),
    )
}

pub fn parse_unknown_argument_test() {
  assert cli.parse(["--wibble"]) == Error(error.UnknownArgument("--wibble"))
}

pub fn parse_missing_value_test() {
  assert cli.parse(["--output"])
    == Error(error.MissingArgumentValue("--output"))
}

// === CONFIG ===============================================================

pub fn defaults_test() {
  assert resolve(no_flags, "", [#("DATABASE_URL", postgres_url)])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: sqlc.PostgreSQL,
      schema: config.FromDatabase(postgres_url),
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
  assert resolve(no_flags, toml, [#("APP_DB", "mysql://root@localhost/app")])
    == Ok(Config(
      output: "src/app/db.gleam",
      engine: sqlc.MySQL,
      schema: config.FromDatabase("mysql://root@localhost/app"),
      sqlc: config.System,
    ))
}

pub fn flags_override_toml_test() {
  let toml =
    "
[tools.parrot]
output = \"src/app/db.gleam\"

[tools.parrot.sqlc]
bin = \"system\"
"
  let flags =
    Flags(..no_flags, output: Some("src/other.gleam"), sqlc: Some("bin/sqlc"))
  assert resolve(flags, toml, [#("DATABASE_URL", postgres_url)])
    == Ok(Config(
      output: "src/other.gleam",
      engine: sqlc.PostgreSQL,
      schema: config.FromDatabase(postgres_url),
      sqlc: config.Binary("bin/sqlc"),
    ))
}

pub fn sqlite_flag_test() {
  let flags = Flags(..no_flags, sqlite: Some("app.db"))
  assert resolve(flags, "", [])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: sqlc.SQLite,
      schema: config.FromDatabase("app.db"),
      sqlc: config.Managed,
    ))
}

pub fn schema_without_database_test() {
  let toml =
    "
[tools.parrot]
engine = \"postgresql\"

[tools.parrot.sqlc]
schema = \"priv/migrations\"
"
  assert resolve(no_flags, toml, [])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: sqlc.PostgreSQL,
      schema: config.FromFiles("priv/migrations"),
      sqlc: config.Managed,
    ))
}

pub fn schema_detects_engine_from_database_url_test() {
  let flags = Flags(..no_flags, schema: Some("priv/schema.sql"))
  let assert Ok(Config(engine: sqlc.PostgreSQL, ..)) =
    resolve(flags, "", [#("DATABASE_URL", postgres_url)])
}

pub fn schema_without_engine_test() {
  let flags = Flags(..no_flags, schema: Some("priv/schema.sql"))
  assert resolve(flags, "", []) == Error(error.MissingEngine)
}

pub fn missing_database_url_test() {
  assert resolve(no_flags, "", [])
    == Error(error.EnvironmentVariableEmpty("DATABASE_URL"))
}

pub fn unknown_engine_test() {
  let flags = Flags(..no_flags, engine: Some("oracle"))
  assert resolve(flags, "", [#("DATABASE_URL", postgres_url)])
    == Error(error.UnknownEngine("oracle"))
}

pub fn wrong_toml_type_test() {
  let assert Error(error.GleamTomlError(_)) =
    resolve(no_flags, "[tools.parrot]\noutput = 1\n", [
      #("DATABASE_URL", postgres_url),
    ])
}
