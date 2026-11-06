//// Generates the gleam module from the output of sqlc:
//// `sqlc.Output` -> `codegen/analyse` -> `codegen/model` -> `codegen/print`.

import child_process
import filepath
import gleam/result
import parrot/internal/codegen/analyse
import parrot/internal/codegen/print
import parrot/internal/command
import parrot/internal/error.{type ParrotError}
import parrot/internal/sqlc
import simplifile

/// Writes the formatted gleam module to `path` and returns the sql types
/// parrot does not know.
///
pub fn generate(
  output: sqlc.Output,
  to path: String,
) -> Result(List(String), ParrotError) {
  use module <- result.try(analyse.module(output))

  let directory = filepath.directory_name(path)
  use _ <- result.try(
    simplifile.create_directory_all(directory)
    |> result.map_error(error.CouldNotWriteModule(directory, _)),
  )
  use _ <- result.try(
    simplifile.write(path, print.module(module))
    |> result.map_error(error.CouldNotWriteModule(path, _)),
  )
  use _ <- result.try(
    child_process.from_name("gleam")
    |> child_process.args(["format", path])
    |> command.run
    |> result.map_error(error.CouldNotFormatModule(path, _)),
  )

  Ok(module.unknown_types)
}
