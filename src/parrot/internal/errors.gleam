pub type ParrotError {
  UnknownEngine(String)

  SqliteDBNotFound(String)
  MySqlDBNotFound(String)
  PostgreSqlDBNotFound(String)

  SqlcDownloadError(String)
  SqlcGenerateError(String)

  NoQueriesFound
  MysqldumpError
  PgdumpError

  CodegenError
}

pub fn err_to_string(error: ParrotError) {
  case error {
    MySqlDBNotFound(_) -> "mysql db not found"
    PostgreSqlDBNotFound(_) -> "postgresql db not found"
    SqliteDBNotFound(_) -> "sqlite db not found"
    MysqldumpError -> "there was an error with mysqldump"
    SqlcDownloadError(e) -> "there was an error downloading sqlc: " <> e
    SqlcGenerateError(e) -> "could not call `sqlc generate`:\n" <> e
    PgdumpError -> "there was an error pg_dump"
    NoQueriesFound -> "no queries were found to codegen"
    UnknownEngine(engine) -> "unknown engine: " <> engine
    CodegenError -> "there was an error during codegen"
  }
}
