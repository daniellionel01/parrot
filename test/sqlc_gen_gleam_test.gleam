import gleeunit
import gleeunit/should
import sqlc_gen_gleam/codegen.{codegen_from_config}
import sqlc_gen_gleam/config.{Config}

pub fn main() {
  gleeunit.main()
}

// pub fn mysql_codegen_test() {
//   Config(
//     json_file_path: "sql/mysql/gen/codegen.json",
//     gleam_module_out_path: "gen/sqlc_mysql.gleam",
//   )
//   |> codegen_from_config()
// }

// pub fn psql_codegen_test() {
//   Config(
//     json_file_path: "sql/psql/gen/codegen.json",
//     gleam_module_out_path: "gen/sqlc_psql.gleam",
//   )
//   |> codegen_from_config()
// }

pub fn sqlite_codegen_test() {
  Config(
    json_file_path: "sql/sqlite/gen/codegen.json",
    gleam_module_out_path: "gen/sqlc_sqlite.gleam",
  )
  |> codegen_from_config()
}
