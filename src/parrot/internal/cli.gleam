import gleam/list
import gleam/option.{type Option, None, Some}
import parrot/error

pub const usage =
  "Generate type-safe Gleam code from SQL queries

Usage: gleam run -m parrot -- [OPTIONS]

Options:
      --sqlite <PATH>    SQLite database file
  -e, --env-var <NAME>   Environment variable with the connection string [default: DATABASE_URL]
      --output <PATH>    Generated module [default: src/<project>/sql.gleam]
      --schema <PATH>    Schema or migration files instead of a database
      --engine <ENGINE>  postgresql, mysql or sqlite [default: from the connection string]
      --sqlc <PATH>      sqlc binary, or \"system\" for sqlc in PATH [default: downloaded by parrot]
  -h, --help             Print help

Examples:
  gleam run -m parrot
  gleam run -m parrot -- --sqlite priv/app.db
  gleam run -m parrot -- --schema priv/migrations --engine postgresql

Options can also be set in gleam.toml: https://parrot.hexdocs.pm/toml-reference.html"

const colorless = "\u{001b}[0m"

pub fn red(text: String) -> String {
  "\u{001b}[31m" <> text <> colorless
}

pub fn yellow(text: String) -> String {
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
    [argument, ..] -> Error(error.InvalidArgument(argument))
  }
}
