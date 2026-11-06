import child_process
import envoy
import filepath
import gleam/int
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/internal/command
import parrot/internal/database
import parrot_test/tooling/pipeline.{type Fixture}

pub const postgres_env = "PARROT_TEST_POSTGRES_URL"

pub const mysql_env = "PARROT_TEST_MYSQL_URL"

/// Returns the connection string of the new database.
///
pub fn create(fixture: Fixture) -> Result(String, String) {
  let name = "parrot_test_" <> fixture.name

  case fixture.engine {
    database.SQLite -> create_sqlite(name, fixture.schema)
    database.PostgreSQL -> create_postgres(name, fixture.schema)
    database.MySQL -> create_mysql(name, fixture.schema)
  }
}

fn create_sqlite(database: String, schema: String) -> Result(String, String) {
  let path = filepath.join(pipeline.scratch_dir(database), "schema.db")

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
    <> "` is not set. Start the test databases with `mise run db-up` and run the "
    <> "integration tests with `mise run test-integration`.",
  )
}

fn parse(url: String) -> Result(uri.Uri, String) {
  uri.parse(url)
  |> result.replace_error("could not parse connection string " <> url)
}

fn exec(
  executable: String,
  arguments: List(String),
  env: List(#(String, String)),
) -> Result(Nil, String) {
  child_process.from_name(executable)
  |> child_process.args(arguments)
  |> child_process.envs(env)
  |> command.run
  |> result.replace(Nil)
  |> result.map_error(fn(e) { "`" <> executable <> "` failed:\n" <> e })
}
