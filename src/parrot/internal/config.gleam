//// Command line flags override `[tools.parrot]` in `gleam.toml`.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import parrot/internal/database.{type Engine}
import parrot/internal/error.{type ParrotError}
import parrot/internal/project
import tom

pub type Config {
  Config(
    /// relative to the project's root
    output: String,
    engine: Engine,
    schema: Schema,
    sqlc: Sqlc,
  )
}

pub type Schema {
  FromDatabase(connection_string: String)
  /// schema or migration files, relative to the project's root
  FromFiles(path: String)
}

pub type Sqlc {
  Managed
  System
  Binary(path: String)
}

pub type Command {
  Help
  Generate(Flags)
}

/// Options passed on the command line. These take precedence over
/// `[tools.parrot]` in gleam.toml.
///
pub type Flags {
  Flags(
    sqlite: Option(String),
    env: Option(String),
    output: Option(String),
    schema: Option(String),
    engine: Option(String),
    sqlc: Option(String),
  )
}

pub const no_flags =
  Flags(
    sqlite: None,
    env: None,
    output: None,
    schema: None,
    engine: None,
    sqlc: None,
  )

pub fn parse(arguments: List(String)) -> Result(Command, error.ParrotError) {
  case list.contains(arguments, "-h") || list.contains(arguments, "--help") {
    True -> Ok(Help)
    False ->
      case arguments {
        ["help"] -> Ok(Help)
        _ -> parse_flags(arguments, no_flags)
      }
  }
}

fn parse_flags(
  arguments: List(String),
  flags: Flags,
) -> Result(Command, error.ParrotError) {
  case arguments {
    [] -> Ok(Generate(flags))
    ["--sqlite", value, ..rest] ->
      parse_flags(rest, Flags(..flags, sqlite: Some(value)))
    ["-e", value, ..rest] | ["--env-var", value, ..rest] ->
      parse_flags(rest, Flags(..flags, env: Some(value)))
    ["--output", value, ..rest] ->
      parse_flags(rest, Flags(..flags, output: Some(value)))
    ["--schema", value, ..rest] ->
      parse_flags(rest, Flags(..flags, schema: Some(value)))
    ["--engine", value, ..rest] ->
      parse_flags(rest, Flags(..flags, engine: Some(value)))
    ["--sqlc", value, ..rest] ->
      parse_flags(rest, Flags(..flags, sqlc: Some(value)))
    [flag]
      if flag == "--sqlite"
      || flag == "-e"
      || flag == "--env-var"
      || flag == "--output"
      || flag == "--schema"
      || flag == "--engine"
      || flag == "--sqlc"
    -> Error(error.MissingFlagValue(flag))
    [argument, ..] -> Error(error.UnknownArgument(argument))
  }
}

pub fn resolve(
  flags: Flags,
  toml: Dict(String, tom.Toml),
  get_env: fn(String) -> Result(String, Nil),
) -> Result(Config, ParrotError) {
  use project_name <- result.try(project.name(toml))
  use output <- result.try(setting(flags.output, toml, ["output"]))
  use env <- result.try(setting(flags.env, toml, ["env"]))
  use engine <- result.try(setting(flags.engine, toml, ["engine"]))
  use schema <- result.try(setting(flags.schema, toml, ["sqlc", "schema"]))
  use bin <- result.try(setting(flags.sqlc, toml, ["sqlc", "bin"]))

  let output = option.unwrap(output, "src/" <> project_name <> "/sql.gleam")
  let env = option.unwrap(env, "DATABASE_URL")
  let sqlc = case bin {
    None -> Managed
    Some("system") -> System
    Some(path) -> Binary(path)
  }
  use engine <- result.try(case engine {
    Some(engine) -> database.engine_from_name(engine) |> result.map(Some)
    None -> Ok(None)
  })

  let connection_string = case flags.sqlite {
    Some(path) -> Some(database.sqlite_url(path))
    None ->
      case get_env(env) {
        Ok("") | Error(_) -> None
        Ok(connection_string) -> Some(connection_string)
      }
  }
  // A connection string from `--sqlite` always has a known engine.
  let detect_engine = fn(connection_string) {
    database.engine_from_url(connection_string)
    |> result.replace_error(error.UnknownConnectionString(env))
  }

  case schema, connection_string {
    Some(path), _ -> {
      use engine <- result.map(case engine, connection_string {
        Some(engine), _ -> Ok(engine)
        None, Some(connection_string) -> detect_engine(connection_string)
        None, None -> Error(error.MissingEngine(schema: path))
      })
      Config(output:, engine:, schema: FromFiles(path), sqlc:)
    }
    None, Some(connection_string) -> {
      use engine <- result.map(case engine {
        Some(engine) -> Ok(engine)
        None -> detect_engine(connection_string)
      })
      Config(output:, engine:, schema: FromDatabase(connection_string), sqlc:)
    }
    None, None -> Error(error.MissingConnectionString(env))
  }
}

/// A command line flag, or else the string at `[tools.parrot.<key>]`.
///
fn setting(
  flag: Option(String),
  toml: Dict(String, tom.Toml),
  key: List(String),
) -> Result(Option(String), ParrotError) {
  case flag {
    Some(value) -> Ok(Some(value))
    None ->
      case tom.get_string(toml, ["tools", "parrot", ..key]) {
        Ok(value) -> Ok(Some(value))
        Error(tom.NotFound(_)) -> Ok(None)
        Error(tom.WrongType(..) as reason) ->
          Error(error.InvalidGleamTomlValue(reason))
      }
  }
}
