//// Configuration for a gleam project which is
//// gathered from command line arguments and the
//// `[tools.parrot]` configuration in `gleam.toml`.
////
//// Command line arguments take precedence over `gleam.toml`.
////

import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import parrot/error.{type ParrotError}
import parrot/internal/cli
import parrot/internal/database.{type Engine}
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

pub fn resolve(
  flags: cli.Flags,
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
  let engine = case engine, connection_string {
    Some(engine), _ -> Ok(engine)
    None, Some(connection_string) -> database.engine_from_url(connection_string)
    None, None -> Error(error.MissingEngine)
  }

  case schema, connection_string {
    Some(path), _ -> {
      use engine <- result.map(engine)
      Config(output:, engine:, schema: FromFiles(path), sqlc:)
    }
    None, Some(connection_string) -> {
      use engine <- result.map(engine)
      Config(output:, engine:, schema: FromDatabase(connection_string), sqlc:)
    }
    None, None -> Error(error.EnvironmentVariableEmpty(env))
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
        Error(tom.WrongType(..)) ->
          Error(error.GleamTomlError(
            "`tools.parrot." <> string.join(key, ".") <> "` must be a string",
          ))
      }
  }
}
