import parrot/error
import parrot/internal/database
import parrot/internal/sqlc

pub fn sqlite_database_does_not_exist_test() {
  let connection_string = database.connection_string("does_not_exist.db")
  assert database.fetch_schema(sqlc.SQLite, connection_string)
    == Error(error.SqliteDBNotFound("does_not_exist.db"))
}
