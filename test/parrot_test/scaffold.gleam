import child_process
import gleam/int
import gleam/string
import simplifile

pub opaque type Project {
  Project(id: String)
}

pub fn tmp(next: fn(Project) -> Nil) {
  let project = new()
  let assert Ok(_) = create(project)
  let assert Ok(_) = build(project)

  next(project)

  let assert Ok(_) = delete(project)
}

pub fn run(project: Project) -> Result(String, String) {
  let exec =
    child_process.exec(
      run: "gleam",
      with: ["run", "--no-print-progress"],
      in: tmp_dir(project),
    )
  case exec {
    Ok(child_process.Output(status_code: _, output:)) -> {
      Ok(output)
    }
    Error(error) -> {
      let error = child_process.describe_start_error(error)
      Error(error)
    }
  }
}

// === === === === === === === === === === === === === === === === === ===

fn new() -> Project {
  let id = random_string(12)
  Project(id:)
}

fn tmp_dir(project: Project) -> String {
  "/tmp/" <> project.id
}

fn build(project: Project) -> Result(Nil, String) {
  let exec =
    child_process.exec(run: "gleam", with: ["build"], in: tmp_dir(project))
  case exec {
    Ok(_) -> {
      Ok(Nil)
    }
    Error(error) -> {
      let error = child_process.describe_start_error(error)
      Error(error)
    }
  }
}

fn create(project: Project) -> Result(Nil, String) {
  let exec =
    child_process.exec(
      run: "gleam",
      with: ["new", project.id, "--name", "app"],
      in: "/tmp",
    )
  case exec {
    Ok(_) -> {
      Ok(Nil)
    }
    Error(error) -> {
      let error = child_process.describe_start_error(error)
      Error(error)
    }
  }
}

fn delete(project: Project) -> Result(Nil, simplifile.FileError) {
  simplifile.delete(tmp_dir(project))
}

// === === === === === === === === === === === === === === === === === ===

const alphabet = "abcdefghijklmnopqrstuvwxyz"

fn random_string(length: Int) {
  do_random_string(length, "")
}

fn do_random_string(length: Int, acc: String) {
  case length {
    0 -> acc
    _ if length < 0 -> acc
    _ -> {
      let index = int.random(string.length(alphabet))
      let char = string.slice(alphabet, index, 1)

      do_random_string(length - 1, acc <> char)
    }
  }
}
