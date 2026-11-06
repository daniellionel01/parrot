//// Generates the gleam module from the JSON sqlc generates:
//// sqlc JSON -> `codegen/analyse` -> `codegen/model` -> `codegen/print`.

import filepath
import gleam/dynamic/decode as d
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import parrot/error
import parrot/internal/codegen/analyse
import parrot/internal/codegen/print
import parrot/internal/sqlc.{type SQLC}
import simplifile

pub type Codegen {
  Codegen(unknown_types: List(String))
}

/// Generates the gleam module at `output` from the JSON sqlc generated.
///
pub fn generate(
  sqlc_json: String,
  output: String,
) -> Result(Codegen, error.ParrotError) {
  use json_string <- result.try(
    simplifile.read(sqlc_json)
    |> result.map_error(error.FileError("read", sqlc_json, _)),
  )

  use dyn_json <- result.try(
    json.parse(from: json_string, using: d.dynamic)
    |> result.replace_error(error.SqlcOutputError("invalid json")),
  )

  use context <- result.try(
    sqlc.decode_sqlc(dyn_json)
    |> result.map_error(fn(errors) {
      errors
      |> list.map(fn(e) {
        "expected "
        <> e.expected
        <> " but found "
        <> e.found
        <> " at "
        <> string.join(e.path, ".")
      })
      |> string.join(", ")
      |> error.SqlcOutputError
    }),
  )

  use module <- result.try(analyse.module(context))
  let module_contents = print.module(module)

  let output_directory = filepath.directory_name(output)
  use _ <- result.try(
    simplifile.create_directory_all(output_directory)
    |> result.map_error(error.FileError("create directory", output_directory, _)),
  )
  use _ <- result.try(
    simplifile.write(to: output, contents: module_contents)
    |> result.map_error(error.FileError("write", output, _)),
  )

  Ok(Codegen(module.unknown_types))
}

/// The source of the gleam module, before formatting.
///
pub fn gleam_module(context: SQLC) -> Result(String, error.ParrotError) {
  use module <- result.map(analyse.module(context))
  print.module(module)
}
