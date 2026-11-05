import gleam/list
import gleam/option.{Some}
import parrot/error
import parrot/internal/cli.{Flags, no_flags}
import parrot/internal/config.{Config}
import parrot/internal/sqlc
import tom

const url = "postgresql://user:pass@localhost/app"

fn resolve(flags: cli.Flags, toml: String, env: List(#(String, String))) {
  let assert Ok(toml) = tom.parse("name = \"app\"\n" <> toml)
  config.resolve(flags, toml, list.key_find(env, _))
}

pub fn parse_test() {
  assert cli.parse(["--output", "src/db.gleam", "-e", "URL"])
    == Ok(cli.Generate(
      Flags(..no_flags, output: Some("src/db.gleam"), env: Some("URL")),
    ))
}

pub fn parse_invalid_test() {
  let assert Error(error.InvalidArgument(_)) = cli.parse(["--wibble"])
  let assert Error(error.InvalidArgument(_)) = cli.parse(["generate"])
}

pub fn defaults_test() {
  assert resolve(no_flags, "", [#("DATABASE_URL", url)])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: sqlc.PostgreSQL,
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
      engine: sqlc.PostgreSQL,
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
    engine: sqlc.SQLite,
    schema: config.FromDatabase("app.db"),
    ..,
  )) = resolve(flags, "", [])
}

pub fn schema_without_database_test() {
  let flags =
    Flags(..no_flags, schema: Some("priv/schema.sql"), engine: Some("mysql"))
  let assert Ok(Config(
    engine: sqlc.MySQL,
    schema: config.FromFiles("priv/schema.sql"),
    ..,
  )) = resolve(flags, "", [])

  let flags = Flags(..no_flags, schema: Some("priv/schema.sql"))
  assert resolve(flags, "", []) == Error(error.MissingEngine)
}
