import parrot/error
import parrot/internal/database

pub fn sqlite_database_does_not_exist_test() {
  assert database.fetch_schema(database.SQLite, "does_not_exist.db")
    == Error(error.SqliteDBNotFound("does_not_exist.db"))
}

pub fn sqlite_url_test() {
  let assert Ok(database.SQLite) = database.engine_from_url("file:app.db")
  assert database.fetch_schema(database.SQLite, "file:does_not_exist.db")
    == Error(error.SqliteDBNotFound("does_not_exist.db"))
  assert database.fetch_schema(database.SQLite, "sqlite://does_not_exist.db")
    == Error(error.SqliteDBNotFound("does_not_exist.db"))
}
