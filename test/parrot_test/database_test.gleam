import argv
import child_process
import gleam/list
import gleam/string
import parrot/error
import parrot/internal/command
import parrot/internal/database
import parrot_test/tooling/fixtures
import parrot_test/tooling/pipeline
import parrot_test/tooling/test_database

pub fn sqlite_database_does_not_exist_test() {
  assert database.fetch_schema(database.SQLite, "does_not_exist.db", in: "/app")
    == Error(error.SqliteDBNotFound("/app/does_not_exist.db"))
}

pub fn sqlite_url_test() {
  let assert Ok(database.SQLite) = database.engine_from_url("file:app.db")
  assert database.fetch_schema(
      database.SQLite,
      "file:does_not_exist.db",
      in: "/app",
    )
    == Error(error.SqliteDBNotFound("/app/does_not_exist.db"))
  assert database.fetch_schema(
      database.SQLite,
      "sqlite:///tmp/app.db",
      in: "/app",
    )
    == Error(error.SqliteDBNotFound("/tmp/app.db"))
}

pub fn sqlite_path_is_relative_to_project_test() {
  use <- integration_only
  let root = pipeline.scratch_dir("sqlite_relative")
  let assert Ok(_) =
    child_process.from_name("sqlite3")
    |> child_process.args(["app.db", "create table t (id integer);"])
    |> child_process.cwd(root)
    |> command.run

  assert database.fetch_schema(database.SQLite, "sqlite:app.db", in: root)
    == Ok("CREATE TABLE t (id integer);")
}

pub fn mysql_password_is_percent_decoded_test() {
  use <- integration_only
  let assert Ok(url) = test_database.create(fixtures.mysql_column_types())
  let assert Ok(url) =
    test_database.mysql_user(
      url,
      "parrot_encoded",
      "p@ss:w/rd",
      "p%40ss%3Aw%2Frd",
    )
  let assert Ok(schema) = database.fetch_schema(database.MySQL, url, in: ".")
  assert string.contains(schema, "CREATE TABLE `accounts`")
}

fn integration_only(test_: fn() -> Nil) -> Nil {
  case list.contains(argv.load().arguments, "integration") {
    True -> test_()
    False -> Nil
  }
}
