//// The gleam project parrot runs in.
////
//// Based off https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel/internal/project.gleam
//// Thank you https://www.github.com/giacomocavalieri
////

import filepath
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import parrot/error
import simplifile
import tom

/// The absolute path of the closest directory with a `gleam.toml`, or else
/// the current directory.
///
pub fn root() -> String {
  case simplifile.current_directory() {
    Ok(cwd) -> find_root(cwd) |> result.unwrap(cwd)
    Error(_) -> "."
  }
}

pub fn find_root(dir: String) -> Result(String, Nil) {
  case simplifile.is_file(filepath.join(dir, "gleam.toml")) {
    Ok(True) -> Ok(dir)
    _ ->
      case filepath.directory_name(dir) {
        parent if parent == dir || parent == "" -> Error(Nil)
        parent -> find_root(parent)
      }
  }
}

/// Where parrot keeps the sqlc binary and its intermediate files.
///
pub fn work_dir(root: String) -> String {
  filepath.join(root, "build/.parrot")
}

pub fn toml(
  root: String,
) -> Result(dict.Dict(String, tom.Toml), error.ParrotError) {
  let toml_path = filepath.join(root, "gleam.toml")

  use toml <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(error.FileError("read", toml_path, _)),
  )
  tom.parse(toml)
  |> result.replace_error(error.GleamTomlError("invalid toml"))
}

pub fn name(
  toml: dict.Dict(String, tom.Toml),
) -> Result(String, error.ParrotError) {
  tom.get_string(toml, ["name"])
  |> result.replace_error(error.GleamTomlError("missing the `name` field"))
}

/// Whether parrot is a regular dependency instead of a dev dependency.
///
pub fn parrot_is_dependency(toml: dict.Dict(String, tom.Toml)) -> Bool {
  result.is_ok(tom.get(toml, ["dependencies", "parrot"]))
}

/// The `*.sql` files inside of every `sql` directory below `dir`, sorted so
/// the generated module is the same on every operating system.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn sql_files(dir: String) -> Result(List(String), error.ParrotError) {
  use files <- result.map(walk(dir))
  list.sort(files, by: string.compare)
}

fn walk(dir: String) -> Result(List(String), error.ParrotError) {
  use entries <- result.try(
    simplifile.read_directory(dir)
    |> result.map_error(error.FileError("read directory", dir, _)),
  )
  let paths = list.map(entries, filepath.join(dir, _))

  case filepath.base_name(dir) {
    "sql" ->
      paths
      |> list.filter(fn(path) {
        filepath.extension(path) == Ok("sql")
        && simplifile.is_file(path) == Ok(True)
      })
      |> Ok
    _ ->
      paths
      |> list.filter(fn(path) { simplifile.is_directory(path) == Ok(True) })
      |> list.try_map(walk)
      |> result.map(list.flatten)
  }
}
