//// Parrot supports Sqlite, PostgreSQL and MySQL.
////
//// This module contains functionality related to working
//// with the different schema files and connection strings.
////

import child_process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/error

pub opaque type ConnectionString {
  ConnectionString(String)
}

pub fn connection_string(value: String) {
  let value = case value {
    "sqlite://" <> value -> value
    "sqlite:" <> value -> value
    value -> value
  }
  ConnectionString(value)
}

pub fn fetch_schema_mysql(
  connection_string: ConnectionString,
) -> Result(String, error.ParrotError) {
  let ConnectionString(connection_string) = connection_string
  let assert Ok(conn) = uri.parse(connection_string)

  let creds = case conn.userinfo {
    option.None -> option.None
    option.Some(userinfo) -> {
      case string.split(userinfo, ":") {
        [user] -> option.Some(#(user, ""))
        [user, pass] -> option.Some(#(user, pass))
        _ -> option.None
      }
    }
  }

  use #(user, pass) <- result.try(option.to_result(
    creds,
    error.MySqlDBNotFound(""),
  ))

  let port = case conn.port {
    option.None -> "3306"
    option.Some(port) -> int.to_string(port)
  }
  let host = case conn.host {
    option.None -> "localhost"
    option.Some(host) -> host
  }
  let db = string.replace(conn.path, "/", "")

  use child_process.Output(status_code: _, output:) <- result.try(
    child_process.exec(
      run: "mysqldump",
      with: ["--no-data", "-u", user, "-p" <> pass, "-h", host, "-P", port, db],
      in: ".",
    )
    |> result.replace_error(error.MysqldumpError),
  )

  output
  |> string.split("\n")
  |> list.filter(fn(line) { string.contains(line, "mysqldump:") == False })
  |> string.join("\n")
  |> Ok
}

pub fn fetch_schema_postgresql(
  connection_string: ConnectionString,
) -> Result(String, error.ParrotError) {
  let ConnectionString(connection_string) = connection_string

  child_process.exec(
    run: "pg_dump",
    with: [
      "--no-privileges",
      "--no-acl",
      "--no-owner",
      "--schema-only",
      "--no-comments",
      "--encoding=utf8",
      connection_string,
    ],
    in: ".",
  )
  |> result.map_error(fn(e) {
    let e = child_process.describe_start_error(e)
    error.PgdumpError(e)
  })
  |> result.map(fn(out) { out.output })
  |> result.map(fn(schema) {
    // this is an edge case with the postgres schema dump.
    // sqlc does not like those lines from postgres 17.
    //
    schema
    |> string.split("\n")
    |> list.filter(fn(line) {
      !string.starts_with(line, "\\restrict")
      && !string.starts_with(line, "\\unrestrict")
    })
    |> string.join("\n")
  })
}

pub fn fetch_schema_sqlite(
  connection_string: ConnectionString,
) -> Result(String, error.ParrotError) {
  let ConnectionString(connection_string) = connection_string

  child_process.exec(
    run: "sqlite3",
    with: [connection_string, ".schema"],
    in: ".",
  )
  |> result.replace_error(error.SqliteDBNotFound(""))
  |> result.map(fn(out) { string.trim(out.output) })
}
