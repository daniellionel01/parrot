import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/internal/errors
import parrot/internal/shellout

pub fn fetch_schema_mysql(db: String) -> Result(String, errors.ParrotError) {
  let assert Ok(conn) = uri.parse(db)

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
    errors.MySqlDBNotFound(""),
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

  use out <- result.try(
    shellout.command(
      run: "mysqldump",
      with: ["--no-data", "-u", user, "-p" <> pass, "-h", host, "-P", port, db],
      in: ".",
      opt: [],
    )
    |> result.replace_error(errors.MysqldumpError),
  )

  out
  |> string.split("\n")
  |> list.filter(fn(line) { string.contains(line, "mysqldump:") == False })
  |> string.join("\n")
  |> Ok
}

pub fn fetch_schema_postgresql(db: String) -> Result(String, errors.ParrotError) {
  shellout.command(
    run: "pg_dump",
    with: [
      "--no-privileges",
      "--no-acl",
      "--no-owner",
      "--schema-only",
      "--no-comments",
      "--encoding=utf8",
      db,
    ],
    in: ".",
    opt: [],
  )
  |> result.replace_error(errors.PgdumpError)
}

pub fn fetch_schema_sqlite(db: String) -> Result(String, errors.ParrotError) {
  let db = case db {
    "sqlite://" <> db -> db
    "sqlite:" <> db -> db
    db -> db
  }

  shellout.command(
    run: "sqlite3",
    with: [
      db,
      ".schema",
    ],
    in: ".",
    opt: [],
  )
  |> result.replace_error(errors.SqliteDBNotFound(""))
}
