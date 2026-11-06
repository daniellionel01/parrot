import gleam/list
import gleam/option.{Some}
import parrot/internal/config.{Config, Flags, no_flags}
import parrot/internal/database
import parrot/internal/error
import tom

const url = "postgresql://user:pass@localhost/app"

fn resolve(
  flags: config.Flags,
  toml: String,
  env: List(#(String, String)),
) -> Result(config.Config, error.ParrotError) {
  let assert Ok(toml) = tom.parse("name = \"app\"\n" <> toml)
  config.resolve(flags, toml, list.key_find(env, _))
}

pub fn parse_test() {
  assert config.parse([
      "--sqlite", "app.db", "-e", "URL", "--output", "src/db.gleam", "--schema",
      "priv/schema.sql", "--engine", "mysql", "--sqlc", "system",
    ])
    == Ok(
      config.Generate(Flags(
        sqlite: Some("app.db"),
        env: Some("URL"),
        output: Some("src/db.gleam"),
        schema: Some("priv/schema.sql"),
        engine: Some("mysql"),
        sqlc: Some("system"),
      )),
    )
  assert config.parse(["--env-var", "URL"])
    == Ok(config.Generate(Flags(..no_flags, env: Some("URL"))))
}

pub fn parse_help_test() {
  assert config.parse(["help"]) == Ok(config.Help)
  assert config.parse(["--sqlite", "app.db", "-h"]) == Ok(config.Help)
}

pub fn parse_invalid_test() {
  assert config.parse(["--wibble"]) == Error(error.UnknownArgument("--wibble"))
  assert config.parse(["generate"]) == Error(error.UnknownArgument("generate"))
  assert config.parse(["--output", "a.gleam", "--sqlite"])
    == Error(error.MissingFlagValue("--sqlite"))
}

pub fn defaults_test() {
  assert resolve(no_flags, "", [#("DATABASE_URL", url)])
    == Ok(Config(
      output: "src/app/sql.gleam",
      engine: database.Postgresql,
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
      engine: database.Postgresql,
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
    engine: database.Sqlite,
    schema: config.FromDatabase("sqlite:app.db"),
    ..,
  )) = resolve(flags, "", [])
}

pub fn schema_without_database_test() {
  let flags =
    Flags(..no_flags, schema: Some("priv/schema.sql"), engine: Some("mysql"))
  let assert Ok(Config(
    engine: database.Mysql,
    schema: config.FromFiles("priv/schema.sql"),
    ..,
  )) = resolve(flags, "", [])

  let flags = Flags(..no_flags, schema: Some("priv/schema.sql"))
  assert resolve(flags, "", [])
    == Error(error.MissingEngine(schema: "priv/schema.sql"))
  assert resolve(flags, "", [#("DATABASE_URL", "wibble://db")])
    == Error(error.UnknownConnectionString("DATABASE_URL"))
}

pub fn sqlite_overrides_env_test() {
  let flags = Flags(..no_flags, sqlite: Some("app.db"))
  let assert Ok(Config(engine: database.Sqlite, ..)) =
    resolve(flags, "", [#("DATABASE_URL", url)])
}

pub fn errors_test() {
  assert resolve(no_flags, "", [])
    == Error(error.MissingConnectionString("DATABASE_URL"))
  assert resolve(no_flags, "[tools.parrot]\nenv = \"APP_DB\"\n", [
      #("APP_DB", ""),
    ])
    == Error(error.MissingConnectionString("APP_DB"))
  assert resolve(no_flags, "", [#("DATABASE_URL", "wibble://db")])
    == Error(error.UnknownConnectionString("DATABASE_URL"))
  assert resolve(Flags(..no_flags, engine: Some("oracle")), "", [
      #("DATABASE_URL", url),
    ])
    == Error(error.UnknownEngine("oracle"))
  let assert Error(error.InvalidGleamTomlValue(tom.WrongType(
    key: ["tools", "parrot", "output"],
    ..,
  ))) =
    resolve(no_flags, "[tools.parrot]\noutput = 1\n", [#("DATABASE_URL", url)])
}
