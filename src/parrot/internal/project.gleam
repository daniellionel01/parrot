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
import simplifile
import tom

pub fn root() -> String {
  find_root(".")
}

pub fn src() -> String {
  filepath.join(root(), "src")
}

/// Name of the gleam application
///
pub fn name() -> String {
  let root = find_root(".")
  let toml_path = filepath.join(root, "gleam.toml")
  let assert Ok(toml) = simplifile.read(toml_path)

  let assert Ok(parsed) = tom.parse(toml)
  let assert Ok(name) = tom.get_string(parsed, ["name"])

  name
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn walk(from: String) -> dict.Dict(String, List(String)) {
  case filepath.base_name(from) {
    "sql" -> {
      let assert Ok(files) = simplifile.read_directory(from)
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
      dict.from_list([#(from, files)])
    }

    _ -> {
      let assert Ok(files) = simplifile.read_directory(from)
      let directories = {
        use file <- list.filter_map(files)
        let file_name = filepath.join(from, file)
        case simplifile.is_directory(file_name) {
          Ok(True) -> Ok(file_name)
          Ok(False) | Error(_) -> Error(Nil)
        }
      }

      list.map(directories, walk)
      |> list.fold(from: dict.new(), with: dict.merge)
    }
  }
}
