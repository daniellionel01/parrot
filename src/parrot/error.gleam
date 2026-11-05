import gleam/int
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

  SqliteDBNotFound(path: String)
  InvalidConnectionString(engine: String, expected: String)

  SchemaDumpError(command: String, output: String)

  SqlcDownloadError(String)
  SqlcNotFound(String)
  SqlcVersionError(String)
  SqlcIntegrityError(expected: String, received: String)
  SqlcGenerateError(String)
  SqlcOutputError(String)

  GleamFormatError(String)

  DuplicateDefinitionError(String, String)
  EmptyEnumError(String)
  DuplicateEnumValueError(String, String, String)
  UnnamedParameterError(query: String, position: Int)
  UnsupportedQueryCommandError(query: String, command: String)
}

pub fn to_string(error: ParrotError) {
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
    InvalidArgument(e) -> {
      e <> ". See `gleam run -m parrot help`."
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
    SqliteDBNotFound(path:) -> {
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
    SqlcVersionError(e) -> {
      "incompatible sqlc version found: " <> e
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
      "there was an error formatting the generated code:" <> err
    }
    DuplicateDefinitionError(name, _) -> {
      "duplicate definition found: '"
      <> name
      <> "' is defined both as an enum and as a query. "
      <> "Consider renaming your query (e.g., to 'Get"
      <> name
      <> "' or 'List"
      <> name
      <> "') to avoid the collision."
    }
    EmptyEnumError(name) -> {
      "enum '"
      <> name
      <> "' has no variants. "
      <> "Empty enums cannot be represented in Gleam. "
      <> "Please add values to the enum or remove it from your schema."
    }
    DuplicateEnumValueError(val_name, enum1, enum2) if enum1 == enum2 -> {
      "enum '"
      <> enum1
      <> "' has multiple values that all become '"
      <> val_name
      <> "' in Gleam. "
      <> "Enum values must still be unique after converting them to PascalCase."
    }
    DuplicateEnumValueError(val_name, enum1, enum2) -> {
      "duplicate enum value '"
      <> val_name
      <> "' found in both '"
      <> enum1
      <> "' and '"
      <> enum2
      <> "'. "
      <> "Enum values must be unique across all enums to avoid naming conflicts in generated Gleam code."
    }
    UnnamedParameterError(query:, position:) -> {
      "parameter $"
      <> int.to_string(position)
      <> " of query '"
      <> query
      <> "' has no name, so parrot can not generate a function argument for it. "
      <> "Please use a named parameter instead, f.e. \"sqlc.arg(name)\" or \"@name\"."
    }
    UnsupportedQueryCommandError(query:, command:) -> {
      "query '"
      <> query
      <> "' uses the annotation :"
      <> string.replace(command, "_", "")
      <> ", which parrot does not support. "
      <> "Supported annotations are :one, :many, :exec and :execresult."
    }
  }
}
