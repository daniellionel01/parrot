import app/sql
import filepath
import gleam/dynamic/decode
import gleam/list
import gleam/option
import parrot/dev
import simplifile
import sqlight

pub fn main() {
  let file_path = filepath.join(root(), "./file.db")
  use conn <- sqlight.with_connection(file_path)

  let #(sql, params) = sql.get_user_by_username("alice")
  let assert Ok([sql.GetUserByUsername(1, "alice", option.Some(_))]) =
    query(conn, sql, params, sql.get_user_by_username_decoder())

  Ok(Nil)
}

fn root() -> String {
  find_root(".")
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}

fn parrot_to_sqlight(param: dev.Param) -> sqlight.Value {
  case param {
    dev.ParamBool(x) -> sqlight.bool(x)
    dev.ParamFloat(x) -> sqlight.float(x)
    dev.ParamInt(x) -> sqlight.int(x)
    dev.ParamString(x) -> sqlight.text(x)
    dev.ParamBitArray(x) -> panic as "bit array needs to be implemented"
    dev.ParamTimestamp(_) ->
      panic as "timestamp parameter needs to be implemented"
    dev.ParamDynamic(_) -> panic as "cannot process dynamic parameter"
  }
}

fn query(
  on on: sqlight.Connection,
  sql sql: String,
  with with: List(dev.Param),
  expecting expecting: decode.Decoder(a),
) {
  let with = list.map(with, parrot_to_sqlight)
  sqlight.query(sql, on:, with:, expecting:)
}
