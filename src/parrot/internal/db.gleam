import child_process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import parrot/internal/error

pub fn fetch_schema_mysql(db: String) -> Result(String, error.ParrotError) {
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
  db: String,
) -> Result(String, error.ParrotError) {
  child_process.exec(
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
  )
  |> result.map_error(fn(e) {
    let e = child_process.describe_start_error(e)
    error.PgdumpError(e)
  })
  |> result.map(fn(out) { out.output })
}

pub fn fetch_schema_sqlite(db: String) -> Result(String, error.ParrotError) {
  child_process.exec(run: "sqlite3", with: [db, ".schema"], in: ".")
  |> result.replace_error(error.SqliteDBNotFound(""))
  |> result.map(fn(out) { out.output })
}
