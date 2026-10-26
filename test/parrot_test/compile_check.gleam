//// Checks that a generated module compiles, by building it inside of a
//// minimal gleam project with the same dependencies a parrot user needs.
////
//// The project is created once by `setup` (so dependencies are only
//// downloaded and compiled a single time) and every `check` only replaces
//// the one module inside of it.
////

import child_process
import filepath
import gleam/result
import parrot/internal/sqlc
import simplifile

const gleam_toml =
  "name = \"compile_check\"
version = \"1.0.0\"

[dependencies]
gleam_stdlib = \">= 0.44.0 and < 2.0.0\"
gleam_time = \">= 1.2.0 and < 2.0.0\"
"

fn dir() -> String {
  filepath.directory_name(sqlc.sqlc_binary_path())
  |> filepath.join("test/_compile_check")
}

pub fn setup() -> Result(Nil, String) {
  let dir = dir()
  let assert Ok(_) = simplifile.create_directory_all(filepath.join(dir, "src"))
  let assert Ok(_) =
    simplifile.write(filepath.join(dir, "gleam.toml"), gleam_toml)
  check("pub fn main() { Nil }")
}

pub fn check(module: String) -> Result(Nil, String) {
  let dir = dir()
  let assert Ok(_) =
    simplifile.write(filepath.join(dir, "src/compile_check.gleam"), module)

  child_process.exec(
    run: "gleam",
    with: ["build", "--no-print-progress"],
    in: dir,
  )
  |> result.map_error(child_process.describe_start_error)
  |> result.try(fn(output) {
    case output {
      child_process.Output(status_code: 0, output: _) -> Ok(Nil)
      child_process.Output(status_code: _, output:) -> Error(output)
    }
  })
}
