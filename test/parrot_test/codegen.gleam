//// We test code generation by doing the following pipeline:
////
//// schema.sql -> sqlc generate json -> codegen gleam module
////
//// We can check this pipeline for different databases,
//// configurations, and scaffolding a gleam application
//// to execute the generated gleam module.
////
//// We have a few ways of validating if our gleam module is correct:
//// - check for the presence of functions signatures and types in the
////   generated gleam module.
//// - running gleam format and build to verify it will compile.
//// - executing the module directly through a database adapter in gleam.
////

import child_process
import filepath
import gleam/dynamic/decode
import gleam/json
import gleam/string
import parrot/internal/codegen
import parrot/internal/sqlc
import simplifile

pub fn sqlite_simple_test() {
  let schema =
    "
create table users (
  id integer primary key autoincrement,
  username text not null unique
);
"
  let queries =
    "
-- name: CountUsers :many
SELECT
  count(*)
FROM
  users;

-- name: CreateUser :exec
INSERT INTO
  users (username)
VALUES
  (?);
"

  let module = gen_module(sqlc.SQLite, schema, queries)

  assert string.contains(module, "pub type CountUsers {")
  assert string.contains(module, "pub fn count_users()")
  assert string.contains(module, "pub fn count_users_decoder()")
  assert string.contains(
    module,
    "pub fn create_user(username username: String)",
  )
}

/// Runs sqlc on the given schema and queries and returns the
/// generated gleam module.
///
fn gen_module(engine: sqlc.Engine, schema: String, queries: String) -> String {
  let dir = filepath.directory_name(sqlc.sqlc_binary_path())
  let assert Ok(_) = sqlc.download_binary()

  let assert Ok(_) = simplifile.write(filepath.join(dir, "schema.sql"), schema)
  let assert Ok(_) =
    simplifile.write(filepath.join(dir, "queries.sql"), queries)
  let assert Ok(_) =
    simplifile.write(
      filepath.join(dir, "sqlc.json"),
      sqlc.gen_sqlc_json(engine, ["queries.sql"]),
    )

  let assert Ok(child_process.Output(status_code: 0, output: _)) =
    sqlc.exec(["generate", "--file", "sqlc.json"])

  let assert Ok(json_string) =
    simplifile.read(filepath.join(dir, "queries.json"))
  let assert Ok(dyn_json) = json.parse(from: json_string, using: decode.dynamic)
  let assert Ok(context) = sqlc.decode_sqlc(dyn_json)
  let assert Ok(module) = codegen.gen_gleam_module(context)
  module
}
