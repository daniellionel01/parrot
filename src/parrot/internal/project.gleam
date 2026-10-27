//// Helps to find information about the current gleam
//// project this program is running in.
////
//// Based off https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel/internal/project.gleam
//// Thank you https://www.github.com/giacomocavalieri
////

import filepath
import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import parrot/error
import simplifile
import tom

pub fn root() -> String {
  // Parrot runs through `gleam run`, which only works inside of a gleam
  // project, so there always is a `gleam.toml`. Should there be none, we
  // stop at the root of the file system instead of searching forever, fall
  // back to the current directory and let reading `gleam.toml` fail.
  let max_depth = case simplifile.current_directory() {
    Ok(cwd) -> list.length(filepath.split(cwd))
    Error(_) -> 0
  }
  find_root(".", max_depth)
}

pub fn src() -> String {
  filepath.join(root(), "src")
}

/// The parsed `gleam.toml` of the project.
///
pub fn toml() -> Result(dict.Dict(String, tom.Toml), error.ParrotError) {
  let toml_path = filepath.join(root(), "gleam.toml")

  use toml <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(error.FileError("read", toml_path, _)),
  )
  tom.parse(toml)
  |> result.replace_error(error.GleamTomlError("invalid toml"))
}

/// Name of the gleam application
///
pub fn name() -> Result(String, error.ParrotError) {
  use toml <- result.try(toml())
  name_from_toml(toml)
}

pub fn name_from_toml(
  toml: dict.Dict(String, tom.Toml),
) -> Result(String, error.ParrotError) {
  tom.get_string(toml, ["name"])
  |> result.replace_error(error.GleamTomlError("missing the `name` field"))
}

fn find_root(path: String, remaining: Int) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml), remaining {
    Ok(True), _ -> path
    _, 0 -> "."
    _, _ -> find_root(filepath.join("..", path), remaining - 1)
  }
}

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn walk(
  from: String,
) -> Result(dict.Dict(String, List(String)), error.ParrotError) {
  use files <- result.try(
    simplifile.read_directory(from)
    |> result.map_error(error.FileError("read directory", from, _)),
  )

  case filepath.base_name(from) {
    "sql" -> {
      let files = {
        use file <- list.filter_map(files)
        use extension <- result.try(filepath.extension(file))
        use <- bool.guard(when: extension != "sql", return: Error(Nil))
        let file_name = filepath.join(from, file)
        case simplifile.is_file(file_name) {
          Ok(True) -> Ok(file_name)
          Ok(False) | Error(_) -> Error(Nil)
        }
      }
      Ok(dict.from_list([#(from, files)]))
    }

    _ -> {
      let directories = {
        use file <- list.filter_map(files)
        let file_name = filepath.join(from, file)
        case simplifile.is_directory(file_name) {
          Ok(True) -> Ok(file_name)
          Ok(False) | Error(_) -> Error(Nil)
        }
      }

      use dicts <- result.map(list.try_map(directories, walk))
      list.fold(dicts, from: dict.new(), with: dict.merge)
    }
  }
}
