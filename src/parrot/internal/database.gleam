//// Parrot supports Sqlite, PostgreSQL and MySQL.
////
//// This module contains functionality related to working
//// with the different schema files and connection strings.
////

import child_process
import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/error
import parrot/internal/sqlc
import simplifile

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

pub fn fetch_schema(engine: sqlc.Engine, connection_string: ConnectionString) {
  let ConnectionString(connection_string) = connection_string

  case engine {
    sqlc.SQLite -> {
      // `sqlite3` would silently create an empty database otherwise.
      use <- bool.guard(
        when: simplifile.is_file(connection_string) != Ok(True),
        return: Error(error.SqliteDBNotFound(connection_string)),
      )

      exec("sqlite3", [connection_string, ".schema"])
      |> result.map(string.trim)
    }
    sqlc.MySQL -> {
      let invalid_connection_string =
        error.InvalidConnectionString(
          "mysql",
          "mysql://user:password@host:port/database",
        )
      use conn <- result.try(
        uri.parse(connection_string)
        |> result.replace_error(invalid_connection_string),
      )

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
        invalid_connection_string,
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

      use output <- result.try(
        exec("mysqldump", [
          "--no-data",
          "-u",
          user,
          "-p" <> pass,
          "-h",
          host,
          "-P",
          port,
          db,
        ]),
      )

      output
      |> string.split("\n")
      |> list.filter(fn(line) { string.contains(line, "mysqldump:") == False })
      |> string.join("\n")
      |> Ok
    }
    sqlc.PostgreSQL -> {
      exec("pg_dump", [
        "--no-privileges",
        "--no-acl",
        "--no-owner",
        "--schema-only",
        "--no-comments",
        "--encoding=utf8",
        connection_string,
      ])
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
  }
}

/// Runs one of the database command line tools and returns its output,
/// if it exited successfully.
///
fn exec(
  command: String,
  arguments: List(String),
) -> Result(String, error.ParrotError) {
  case child_process.exec(run: command, with: arguments, in: ".") {
    Ok(child_process.Output(status_code: 0, output:)) -> Ok(output)
    Ok(child_process.Output(status_code: _, output:)) ->
      Error(error.SchemaDumpError(command, string.trim(output)))
    Error(e) ->
      Error(error.SchemaDumpError(
        command,
        child_process.describe_start_error(e),
      ))
  }
}
