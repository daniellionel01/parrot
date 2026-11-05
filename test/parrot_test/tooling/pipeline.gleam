//// schema.sql + queries.sql -> sqlc -> gleam module, without a database.

import child_process
import filepath
import gleam/dynamic/decode
import gleam/json
import gleam/result
import parrot/error
import parrot/internal/codegen
import parrot/internal/sqlc
import simplifile

pub type Fixture {
  Fixture(name: String, engine: sqlc.Engine, schema: String, queries: String)
}

pub type Output {
  Output(context: sqlc.SQLC, module: String)
}

/// Loads a fixture from `test/fixtures/<name>/{schema,queries}.sql`.
///
pub fn from_files(name: String, engine: sqlc.Engine) -> Fixture {
  let dir = filepath.join("test/fixtures", name)
  let assert Ok(schema) = simplifile.read(filepath.join(dir, "schema.sql"))
  let assert Ok(queries) = simplifile.read(filepath.join(dir, "queries.sql"))
  Fixture(name:, engine:, schema:, queries:)
}

pub fn run(fixture: Fixture) -> Result(Output, error.ParrotError) {
  let sqlc_dir = filepath.directory_name(sqlc.sqlc_binary_path())
  let relative_dir = filepath.join("test", fixture.name)
  let dir = filepath.join(sqlc_dir, relative_dir)

  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir)
  let assert Ok(_) =
    simplifile.write(filepath.join(dir, "schema.sql"), fixture.schema)
  let assert Ok(_) =
    simplifile.write(filepath.join(dir, "queries.sql"), fixture.queries)
  let assert Ok(_) =
    simplifile.write(
      filepath.join(dir, "sqlc.json"),
      sqlc.gen_sqlc_json(fixture.engine, "schema.sql", ["queries.sql"]),
    )

  use _ <- result.try(
    case
      sqlc.exec(sqlc.sqlc_binary_path(), [
        "generate",
        "--file",
        filepath.join(relative_dir, "sqlc.json"),
      ])
    {
      Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
      Ok(child_process.Output(status_code: _, output:)) ->
        Error(error.SqlcGenerateError(output))
      Error(e) ->
        Error(error.SqlcGenerateError(child_process.describe_start_error(e)))
    },
  )

  let assert Ok(json_string) =
    simplifile.read(filepath.join(dir, "queries.json"))
  let assert Ok(dyn_json) = json.parse(from: json_string, using: decode.dynamic)
  let assert Ok(context) = sqlc.decode_sqlc(dyn_json)
  use module <- result.try(codegen.gen_gleam_module(context))
  Ok(Output(context:, module: format(module, in: dir)))
}

/// Parrot formats the generated module, so the snapshots do too.
///
pub fn format(module: String, in dir: String) -> String {
  let path = filepath.join(dir, "sql.gleam")
  let assert Ok(_) = simplifile.write(path, module)
  let assert Ok(child_process.Output(status_code: 0, output: _)) =
    child_process.exec(run: "gleam", with: ["format", "sql.gleam"], in: dir)
  let assert Ok(module) = simplifile.read(path)
  module
}
