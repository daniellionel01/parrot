//// schema.sql + queries.sql -> sqlc -> gleam module, without a database.

import filepath
import gleam/result
import parrot/error
import parrot/internal/codegen
import parrot/internal/database.{type Engine}
import parrot/internal/project
import parrot/internal/sqlc
import simplifile

pub type Fixture {
  Fixture(name: String, engine: Engine, schema: String, queries: String)
}

pub type Output {
  Output(sqlc: sqlc.Output, module: String, unknown_types: List(String))
}

/// Loads a fixture from `test/fixtures/<name>/{schema,queries}.sql`.
///
pub fn from_files(name: String, engine: Engine) -> Fixture {
  let dir = filepath.join("test/fixtures", name)
  let assert Ok(schema) = simplifile.read(filepath.join(dir, "schema.sql"))
  let assert Ok(queries) = simplifile.read(filepath.join(dir, "queries.sql"))
  Fixture(name:, engine:, schema:, queries:)
}

/// Lays the fixture out like a project, so sqlc runs in `build/.parrot` with
/// paths into `src` and `priv`, the same as for `gleam run -m parrot`.
///
pub fn run(fixture: Fixture) -> Result(Output, error.ParrotError) {
  let root = scratch_dir(fixture.name)
  let schema = sqlc.SchemaFiles(write(root, "priv/schema.sql", fixture.schema))
  let queries = write(root, "src/app/sql/queries.sql", fixture.queries)
  let module = filepath.join(root, "src/app/sql.gleam")
  let assert Ok(binary) =
    sqlc.managed_binary(in: project.work_dir(project.root()))

  use output <- result.try(
    sqlc.generate(
      binary,
      in: filepath.join(root, "build/.parrot"),
      engine: fixture.engine,
      schema:,
      queries: [queries],
    ),
  )
  use unknown_types <- result.try(codegen.generate(output, to: module))
  let assert Ok(module) = simplifile.read(module)
  Ok(Output(sqlc: output, module:, unknown_types:))
}

fn write(root: String, path: String, contents: String) -> String {
  let path = filepath.join(root, path)
  let assert Ok(_) =
    simplifile.create_directory_all(filepath.directory_name(path))
  let assert Ok(_) = simplifile.write(path, contents)
  path
}

/// An empty directory for a test's files.
///
pub fn scratch_dir(name: String) -> String {
  let dir = filepath.join(project.work_dir(project.root()), "test/" <> name)
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir)
  dir
}
