pub type ParrotError {
  UnknownEngine(String)

  SqliteDBNotFound(String)
  MySqlDBNotFound(String)
  PostgreSqlDBNotFound(String)

  SchemaFileError

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
}

pub fn err_to_string(error: ParrotError) {
  case error {
    MySqlDBNotFound(_) -> "mysql db not found"
    PostgreSqlDBNotFound(_) -> "postgresql db not found"
    SqliteDBNotFound(_) -> "sqlite db not found"
    SchemaFileError -> "there was an error reading the specified schema file"
    MysqldumpError -> "there was an error with mysqldump"
    SqlcDownloadError(e) -> "there was an error downloading sqlc: " <> e
    SqlcVersionError(e) -> "incompatible sqlc version found: " <> e
    SqlcGenerateError(e) -> "could not call `sqlc generate`:\n" <> e
    PgdumpError(e) -> e
    NoQueriesFound -> "no queries were found to codegen"
    UnknownEngine(engine) -> "unknown engine: " <> engine
    CodegenError -> "there was an error during codegen"
    GleamFormatError(err) ->
      "there was an error formatting the generated code:" <> err
    DuplicateDefinitionError(name, _) ->
      "duplicate definition found: '"
      <> name
      <> "' is defined both as an enum and as a query. "
      <> "Consider renaming your query (e.g., to 'Get"
      <> name
      <> "' or 'List"
      <> name
      <> "') to avoid the collision."
    EmptyEnumError(name) ->
      "enum '"
      <> name
      <> "' has no variants. "
      <> "Empty enums cannot be represented in Gleam. "
      <> "Please add values to the enum or remove it from your schema."
    DuplicateEnumValueError(val_name, enum1, enum2) ->
      "duplicate enum value '"
      <> val_name
      <> "' found in both '"
      <> enum1
      <> "' and '"
      <> enum2
      <> "'. "
      <> "Enum values must be unique across all enums to avoid naming conflicts in generated Gleam code."
  }
}
