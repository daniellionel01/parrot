//// Everything that differs between SQLite, PostgreSQL and MySQL, apart from
//// their column types: connection strings and fetching the schema.
////

import child_process
import filepath
import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/internal/command
import parrot/internal/error.{type ParrotError}
import simplifile

pub type Engine {
  Sqlite
  Mysql
  Postgresql
}

pub fn engine_name(engine: Engine) -> String {
  case engine {
    Sqlite -> "sqlite"
    Mysql -> "mysql"
    Postgresql -> "postgresql"
  }
}

pub fn engine_from_name(name: String) -> Result(Engine, ParrotError) {
  case string.lowercase(name) {
    "postgresql" | "postgres" -> Ok(Postgresql)
    "mysql" -> Ok(Mysql)
    "sqlite" -> Ok(Sqlite)
    _ -> Error(error.UnknownEngine(name))
  }
}

pub fn engine_from_url(url: String) -> Result(Engine, Nil) {
  case url {
    "postgres" <> _ -> Ok(Postgresql)
    "mysql" <> _ -> Ok(Mysql)
    "sqlite" <> _ | "file:" <> _ -> Ok(Sqlite)
    _ -> Error(Nil)
  }
}

pub fn sqlite_url(path: String) -> String {
  "sqlite:" <> path
}

/// Relative sqlite paths are resolved from `directory`, the project's root, the
/// same as by the application.
///
pub fn fetch_schema(
  engine: Engine,
  url: String,
  in directory: String,
) -> Result(String, ParrotError) {
  case engine {
    Sqlite -> fetch_sqlite(sqlite_path(url, directory))
    Mysql -> fetch_mysql(url)
    Postgresql -> fetch_postgres(url)
  }
}

/// sqlite connection strings may also just be a path.
///
fn sqlite_path(url: String, directory: String) -> String {
  let path = case url {
    "sqlite://" <> path | "sqlite:" <> path -> path
    "file://" <> path | "file:" <> path -> path
    path -> path
  }
  case filepath.is_absolute(path) {
    True -> path
    False -> filepath.join(directory, path)
  }
}

fn fetch_sqlite(path: String) -> Result(String, ParrotError) {
  // `sqlite3` would silently create an empty database otherwise.
  use <- bool.guard(
    when: simplifile.is_file(path) != Ok(True),
    return: Error(error.SqliteDatabaseNotFound(path)),
  )
  dump("sqlite3", [path, ".schema"], [])
  |> result.map(string.trim)
}

fn fetch_mysql(url: String) -> Result(String, ParrotError) {
  let invalid =
    error.InvalidConnectionString("mysql://user:password@host:port/database")
  use conn <- result.try(uri.parse(url) |> result.replace_error(invalid))
  use userinfo <- result.try(option.to_result(conn.userinfo, invalid))
  let #(user, password) =
    string.split_once(userinfo, ":") |> result.unwrap(#(userinfo, ""))
  use user <- result.try(
    uri.percent_decode(user) |> result.replace_error(invalid),
  )
  use password <- result.try(
    uri.percent_decode(password) |> result.replace_error(invalid),
  )

  dump(
    "mysqldump",
    [
      "--no-data",
      "--user=" <> user,
      "--host=" <> option.unwrap(conn.host, "localhost"),
      "--port=" <> int.to_string(option.unwrap(conn.port, 3306)),
      string.replace(conn.path, "/", ""),
    ],
    // mysqldump warns about passwords passed as an argument.
    [#("MYSQL_PWD", password)],
  )
}

fn fetch_postgres(url: String) -> Result(String, ParrotError) {
  use schema <- result.map(
    dump(
      "pg_dump",
      [
        "--no-privileges",
        "--no-acl",
        "--no-owner",
        "--schema-only",
        "--no-comments",
        "--encoding=utf8",
        url,
      ],
      [],
    ),
  )
  // pg_dump 17.6+ adds `\restrict` lines, which sqlc can not parse.
  schema
  |> string.split("\n")
  |> list.filter(fn(line) {
    !string.starts_with(line, "\\restrict")
    && !string.starts_with(line, "\\unrestrict")
  })
  |> string.join("\n")
}

fn dump(
  executable: String,
  arguments: List(String),
  env: List(#(String, String)),
) -> Result(String, ParrotError) {
  child_process.from_name(executable)
  |> child_process.args(arguments)
  |> child_process.envs(env)
  |> command.output
  |> result.map_error(error.CouldNotFetchSchema(executable, _))
}
