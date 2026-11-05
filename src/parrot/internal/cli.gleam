//// Contains functionality related to the command line
//// and rendering text in the terminal.
////

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import hoist
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
  use specs <- result.try(
    hoist.validate_flag_specs([
      hoist.new_flag("sqlite"),
      hoist.new_flag("env-var") |> hoist.with_short_alias("e"),
      hoist.new_flag("output"),
      hoist.new_flag("schema"),
      hoist.new_flag("engine"),
      hoist.new_flag("sqlc"),
      hoist.new_flag("help") |> hoist.with_short_alias("h") |> hoist.as_toggle,
    ])
    |> result.replace_error(error.InvalidArgument(
      "invalid flag definitions, please open an issue",
    )),
  )
  use args <- result.try(
    hoist.parse(arguments, specs)
    |> result.map_error(fn(e) {
      error.InvalidArgument(case e {
        hoist.UnknownFlag(flag) -> "unknown flag `" <> flag <> "`"
        hoist.ValueNotProvided(flag) -> "missing value for `--" <> flag <> "`"
        hoist.ValueNotSupported(flag:, ..) ->
          "`--" <> flag <> "` does not take a value"
        hoist.CustomError(Nil) -> "invalid arguments"
      })
    }),
  )

  let help = list.contains(args.flags, hoist.ToggleFlag("help"))
  case args.arguments, help {
    ["help"], _ | [], True -> Ok(Help)
    [], False -> Ok(Generate(list.fold(args.flags, no_flags, add_flag)))
    [argument, ..], _ ->
      Error(error.InvalidArgument("unknown argument `" <> argument <> "`"))
  }
}

fn add_flag(flags: Flags, flag: hoist.Flag) -> Flags {
  case flag {
    hoist.ValueFlag("sqlite", value) -> Flags(..flags, sqlite: Some(value))
    hoist.ValueFlag("env-var", value) -> Flags(..flags, env: Some(value))
    hoist.ValueFlag("output", value) -> Flags(..flags, output: Some(value))
    hoist.ValueFlag("schema", value) -> Flags(..flags, schema: Some(value))
    hoist.ValueFlag("engine", value) -> Flags(..flags, engine: Some(value))
    hoist.ValueFlag("sqlc", value) -> Flags(..flags, sqlc: Some(value))
    _ -> flags
  }
}
