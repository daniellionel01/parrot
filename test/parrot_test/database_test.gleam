import gleam/string
import parrot/error
import parrot/internal/database
import parrot/internal/sqlc

pub fn sqlite_database_does_not_exist_test() {
  let result =
    database.fetch_schema(
      sqlc.SQLite,
      database.connection_string("sqlite://does_not_exist.db"),
    )
  assert result == Error(error.SqliteDBNotFound("does_not_exist.db"))
}

pub fn mysql_connection_string_without_credentials_test() {
  let assert Error(error.InvalidConnectionString(engine: "mysql", expected: _)) =
    database.fetch_schema(
      sqlc.MySQL,
      database.connection_string("mysql://127.0.0.1:3306/app"),
    )
}

pub fn invalid_connection_string_does_not_leak_password_test() {
  let assert Error(e) =
    database.fetch_schema(
      sqlc.MySQL,
      database.connection_string("mysql://user:secret@[invalid/app"),
    )
  assert !string.contains(error.to_string(e), "secret")
}
