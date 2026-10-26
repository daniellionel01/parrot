import gleam/int
import gleam/string

pub type ParrotError {
  EnvironmentVariableEmpty(String)
  UnknownEngine(String)

  SqliteDBNotFound(String)
  MySqlDBNotFound(String)
  PostgreSqlDBNotFound(String)

  SqlcDownloadError(String)
  SqlcVersionError(String)
  SqlcGenerateError(String)

  GleamFormatError(String)

  NoQueriesFound
  MysqldumpError
  PgdumpError(String)

  CodegenError
  DuplicateDefinitionError(String, String)
  EmptyEnumError(String)
  DuplicateEnumValueError(String, String, String)
  UnnamedParameterError(query: String, position: Int)
  UnsupportedQueryCommandError(query: String, command: String)
  SqlcIntegrityError(expected: String, received: String)
}

pub fn to_string(error: ParrotError) {
  case error {
    EnvironmentVariableEmpty(e) -> {
      "Environment Variable \"" <> e <> "\" is empty!"
    }
    MySqlDBNotFound(_) -> {
      "mysql db not found"
    }
    PostgreSqlDBNotFound(_) -> {
      "postgresql db not found"
    }
    SqliteDBNotFound(_) -> {
      "sqlite db not found"
    }
    MysqldumpError -> {
      "there was an error with mysqldump"
    }
    SqlcDownloadError(e) -> {
      "there was an error downloading sqlc: " <> e
    }
    SqlcVersionError(e) -> {
      "incompatible sqlc version found: " <> e
    }
    SqlcGenerateError(e) -> {
      "could not call `sqlc generate`:\n" <> e
    }
    PgdumpError(e) -> {
      e
    }
    NoQueriesFound -> {
      "no queries were found to codegen"
    }
    UnknownEngine(engine) -> {
      "unknown engine: " <> engine
    }
    CodegenError -> {
      "there was an error during codegen"
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
    SqlcIntegrityError(expected:, received:) -> {
      "the sqlc binary does not match the expected checksum. "
      <> "This could mean the download was corrupted or tampered with.\n"
      <> "expected: "
      <> expected
      <> "\nreceived: "
      <> received
    }
  }
}
