//// Contains functionality related to the command line
//// and rendering text in the terminal.
////

import gleam/list
import gleam/option.{type Option, None, Some}
import parrot/error

pub const usage_text =
  "
  🦜 Parrot - type-safe SQL in gleam for sqlite, postgresql & mysql

  USAGE:
    gleam run -m parrot -- [OPTIONS]
    gleam run -m parrot help

  OPTIONS:
    --sqlite <PATH>        sqlite database file
    -e, --env-var <NAME>   environment variable with the connection string (default: DATABASE_URL)
    --output <PATH>        generated module (default: src/<project>/sql.gleam)
    --schema <PATH>        schema or migration files instead of a database connection
    --engine <ENGINE>      postgresql, mysql or sqlite (default: detected from the connection string)
    --sqlc <PATH|system>   sqlc binary to use instead of the one parrot downloads

  Options can also be set in gleam.toml under [tools.parrot], see
  https://github.com/daniellionel01/parrot/blob/main/pages/toml-reference.md

  CONNECTION STRINGS:
    postgresql://user:password@host:port/database
    mysql://user:password@host:port/database
    sqlite:path/to/database.db

  EXAMPLES:
    gleam run -m parrot
    gleam run -m parrot -- --sqlite priv/app.db
    gleam run -m parrot -- --schema priv/migrations --engine postgresql
"

pub const colorless = "\u{001b}[0m"

pub const error_crossmark = "\u{274C}"

pub fn green(text: String) {
  "\u{001b}[32m" <> text <> colorless
}

pub fn red(text: String) {
  "\u{001b}[31m" <> text <> colorless
}

pub fn yellow(text: String) {
  "\u{001b}[33m" <> text <> colorless
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
  case arguments {
    ["help"] | ["--help"] | ["-h"] -> Ok(Help)
    _ -> parse_flags(arguments, no_flags)
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
    [argument, ..] ->
      case
        list.contains(
          [
            "--sqlite",
            "-e",
            "--env-var",
            "--output",
            "--schema",
            "--engine",
            "--sqlc",
          ],
          argument,
        )
      {
        True -> Error(error.MissingArgumentValue(argument))
        False -> Error(error.UnknownArgument(argument))
      }
  }
}
