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

pub fn sqlite_simple_test() {
  let schema =
    "
create table users (
  id integer primary key autoincrement,
  username text not null unique,
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

  todo as "sqlc generate"
}
