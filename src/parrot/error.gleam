import gleam/int
import gleam/list
import gleam/string
import simplifile

pub type ParrotError {
  EnvironmentVariableEmpty(String)
  UnknownEngine(String)
  /// Using schema files without a connection string, so the engine can't be
  /// detected.
  MissingEngine
  InvalidArgument(String)

  /// The project's `gleam.toml` could not be read or is missing a field.
  GleamTomlError(String)
  FileError(action: String, path: String, reason: simplifile.FileError)
  NoQueriesFound

  SqliteDatabaseNotFound(path: String)
  InvalidConnectionString(engine: String, expected: String)

  SchemaDumpError(command: String, output: String)

  SqlcDownloadError(String)
  SqlcNotFound(String)
  SqlcIntegrityError(expected: String, received: String)
  SqlcGenerateError(String)
  SqlcOutputError(String)

  GleamFormatError(String)

  /// Two definitions of the generated module have the same name.
  DuplicateDefinitionError(name: String, first: Definition, second: Definition)
  EmptyEnumError(String)
  UnnamedParameterError(query: String, position: Int)
  UnsupportedQueryCommandError(
    query: String,
    command: String,
    supported: List(String),
  )
  UnsupportedEmbedError(query: String)
}

/// What a definition of the generated module is generated from.
pub type Definition {
  /// The code that is the same in every generated module, its imports and
  /// gleam's prelude.
  RuntimeDefinition
  /// The enum's type and functions.
  EnumDefinition(enum: String)
  /// The constructor of one of the enum's values.
  EnumValueDefinition(enum: String, value: String)
  /// The query's function and, if it returns rows, the row's type,
  /// constructor and decoder.
  QueryDefinition(query: String)
}

pub fn to_string(error: ParrotError) -> String {
  case error {
    EnvironmentVariableEmpty(e) -> {
      "Environment Variable \"" <> e <> "\" is empty!"
    }
    UnknownEngine(engine) -> {
      "unknown engine: " <> engine <> ". Expected postgresql, mysql or sqlite."
    }
    MissingEngine -> {
      "could not detect the database engine. Set `engine` in "
      <> "`[tools.parrot]` or pass `--engine`."
    }
    InvalidArgument(argument) -> {
      "invalid argument `"
      <> argument
      <> "`. See `gleam run -m parrot -- --help`."
    }
    GleamTomlError(e) -> {
      "could not read the project's gleam.toml: " <> e
    }
    FileError(action:, path:, reason:) -> {
      "could not "
      <> action
      <> " `"
      <> path
      <> "`: "
      <> simplifile.describe_error(reason)
    }
    NoQueriesFound -> {
      "no queries were found. Parrot looks for `*.sql` files inside of "
      <> "`sql` directories in `src`, f.e. `src/app/sql/users.sql`."
    }
    SqliteDatabaseNotFound(path:) -> {
      "sqlite database `" <> path <> "` does not exist"
    }
    InvalidConnectionString(engine:, expected:) -> {
      "could not parse the "
      <> engine
      <> " connection string. Expected the format: "
      <> expected
    }
    SchemaDumpError(command:, output:) -> {
      "could not fetch the database schema with `"
      <> command
      <> "`:\n"
      <> output
    }
    SqlcNotFound(e) -> {
      "could not run sqlc: " <> e
    }
    SqlcDownloadError(e) -> {
      "there was an error downloading sqlc: " <> e
    }
    SqlcIntegrityError(expected:, received:) -> {
      "the sqlc binary does not match the expected checksum. "
      <> "This could mean the download was corrupted or tampered with.\n"
      <> "expected: "
      <> expected
      <> "\nreceived: "
      <> received
    }
    SqlcGenerateError(e) -> {
      "could not call `sqlc generate`:\n" <> e
    }
    SqlcOutputError(e) -> {
      "could not read the output of sqlc: "
      <> e
      <> "\nThis is most likely a bug in parrot, please open an issue: "
      <> "https://github.com/daniellionel01/parrot/issues"
    }
    GleamFormatError(err) -> {
      "there was an error formatting the generated code:\n" <> err
    }
    DuplicateDefinitionError(name:, first:, second:) -> {
      "`"
      <> name
      <> "` would be defined twice in the generated module, by "
      <> describe_definition(first)
      <> " and by "
      <> describe_definition(second)
      <> ". "
      <> case first, second {
        _, QueryDefinition(query:) | QueryDefinition(query:), _ ->
          "Consider renaming the query '" <> query <> "'."
        RuntimeDefinition, _ | _, RuntimeDefinition ->
          "Parrot can not generate this name yet, please open an issue: "
          <> "https://github.com/daniellionel01/parrot/issues"
        _, _ ->
          "Names in a gleam module must be unique, after parrot converts "
          <> "enum names and values to PascalCase."
      }
    }
    EmptyEnumError(name) -> {
      "enum '"
      <> name
      <> "' has no variants. "
      <> "Empty enums cannot be represented in Gleam. "
      <> "Please add values to the enum or remove it from your schema."
    }
    UnnamedParameterError(query:, position:) -> {
      "parameter $"
      <> int.to_string(position)
      <> " of query '"
      <> query
      <> "' has no name, so parrot can not generate a function argument for it. "
      <> "Please use a named parameter instead, f.e. \"sqlc.arg(name)\" or \"@name\"."
    }
    UnsupportedEmbedError(query:) -> {
      "query '"
      <> query
      <> "' uses `sqlc.embed`, which parrot does not support yet. "
      <> "Select the columns instead."
    }
    UnsupportedQueryCommandError(query:, command:, supported:) -> {
      "query '"
      <> query
      <> "' uses the annotation "
      <> command
      <> ", which parrot does not support. "
      <> "Supported annotations are "
      <> enumerate(supported)
      <> "."
    }
  }
}

fn describe_definition(definition: Definition) -> String {
  case definition {
    RuntimeDefinition -> "parrot's own code"
    EnumDefinition(enum:) -> "enum '" <> enum <> "'"
    EnumValueDefinition(enum:, value:) ->
      "value '" <> value <> "' of enum '" <> enum <> "'"
    QueryDefinition(query:) -> "query '" <> query <> "'"
  }
}

/// `a, b and c`
fn enumerate(items: List(String)) -> String {
  case list.reverse(items) {
    [] -> ""
    [last] -> last
    [last, ..rest] -> string.join(list.reverse(rest), ", ") <> " and " <> last
  }
}
