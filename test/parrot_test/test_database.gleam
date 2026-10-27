import child_process
import child_process/stdio
import envoy
import filepath
import gleam/int
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/internal/sqlc
import parrot_test/pipeline.{type Fixture}
import simplifile

pub const postgres_env = "PARROT_TEST_POSTGRES_URL"

pub const mysql_env = "PARROT_TEST_MYSQL_URL"

/// Returns the connection string of the new database.
///
pub fn create(fixture: Fixture) -> Result(String, String) {
  let database = "parrot_test_" <> fixture.name

  case fixture.engine {
    sqlc.SQLite -> create_sqlite(database, fixture.schema)
    sqlc.PostgreSQL -> create_postgres(database, fixture.schema)
    sqlc.MySQL -> create_mysql(database, fixture.schema)
  }
}

fn create_sqlite(database: String, schema: String) -> Result(String, String) {
  let dir =
    filepath.directory_name(sqlc.sqlc_binary_path())
    |> filepath.join("test/_databases")
  let assert Ok(_) = simplifile.create_directory_all(dir)
  let path = filepath.join(dir, database <> ".db")
  let _ = simplifile.delete(path)

  use _ <- result.map(exec("sqlite3", [path, schema], []))
  path
}

fn create_postgres(database: String, schema: String) -> Result(String, String) {
  use url <- result.try(base_url(postgres_env))
  use parsed <- result.try(parse(url))
  let database_url = uri.to_string(uri.Uri(..parsed, path: "/" <> database))

  use _ <- result.try(
    exec(
      "psql",
      [
        url,
        "--quiet",
        "--set=ON_ERROR_STOP=1",
        "--command=drop database if exists " <> database,
        "--command=create database " <> database,
      ],
      [],
    ),
  )
  use _ <- result.map(
    exec(
      "psql",
      [database_url, "--quiet", "--set=ON_ERROR_STOP=1", "--command=" <> schema],
      [],
    ),
  )
  database_url
}

fn create_mysql(database: String, schema: String) -> Result(String, String) {
  use url <- result.try(base_url(mysql_env))
  use parsed <- result.try(parse(url))
  let database_url = uri.to_string(uri.Uri(..parsed, path: "/" <> database))

  let #(user, password) = case parsed.userinfo {
    option.Some(userinfo) ->
      case string.split_once(userinfo, ":") {
        Ok(#(user, password)) -> #(user, password)
        Error(_) -> #(userinfo, "")
      }
    option.None -> #("root", "")
  }
  let connection = [
    "--protocol=TCP",
    "--host=" <> option.unwrap(parsed.host, "127.0.0.1"),
    "--port=" <> int.to_string(option.unwrap(parsed.port, 3306)),
    "--user=" <> user,
  ]
  // passing the password as an environment variable avoids the warning
  // mysql prints when it is passed as an argument.
  let env = [#("MYSQL_PWD", password)]

  use _ <- result.try(exec(
    "mysql",
    [
      "--execute=drop database if exists "
        <> database
        <> "; create database "
        <> database
        <> ";",
      ..connection
    ],
    env,
  ))
  use _ <- result.map(exec(
    "mysql",
    ["--database=" <> database, "--execute=" <> schema, ..connection],
    env,
  ))
  database_url
}

fn base_url(env: String) -> Result(String, String) {
  envoy.get(env)
  |> result.replace_error(
    "environment variable `"
    <> env
    <> "` is not set. Start the test databases with `just db-up` and run the "
    <> "integration tests with `just test-integration`.",
  )
}

fn parse(url: String) -> Result(uri.Uri, String) {
  uri.parse(url)
  |> result.replace_error("could not parse connection string " <> url)
}

fn exec(
  command: String,
  arguments: List(String),
  env: List(#(String, String)),
) -> Result(Nil, String) {
  let result = case child_process.find_executable(command) {
    Error(_) -> Error("`" <> command <> "` is not installed")
    Ok(path) ->
      child_process.from_file(path)
      |> child_process.args(arguments)
      |> child_process.envs(env)
      |> child_process.run(stdio.capture(True))
      |> result.map_error(child_process.describe_start_error)
  }

  case result {
    Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
    Ok(child_process.Output(status_code: _, output:)) ->
      Error("`" <> command <> "` failed:\n" <> output)
    Error(e) -> Error(e)
  }
}
