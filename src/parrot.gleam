import argv
import child_process
import filepath
import gleam/bool
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import parrot/error
import parrot/internal/cli
import parrot/internal/codegen
import parrot/internal/config
import parrot/internal/database
import parrot/internal/project
import parrot/internal/sqlc
import simplifile

pub fn main() {
  let result = {
    use command <- result.try(cli.parse(argv.load().arguments))
    case command {
      cli.Help -> Ok(cli.usage_text)
      cli.Generate(flags) -> {
        use config <- result.try(config.load(flags))
        use _ <- result.map(generate(config))
        "\u{1F99C} SQL successfully generated!"
      }
    }
  }

  case result {
    Ok(text) -> {
      io.println(text)
      exit(0)
    }
    Error(e) -> {
      io.println(cli.red("\nError: " <> error.to_string(e)))
      exit(1)
    }
  }
}

/// exit(0) -> success
/// exit(1) -> failure
///
@external(erlang, "parrot_ffi", "exit")
fn exit(n: Int) -> Nil

fn generate(config: config.Config) -> Result(Nil, error.ParrotError) {
  use files <- result.try(project.walk(project.src()))
  let queries =
    files
    |> dict.values
    |> list.flatten
    |> list.map(from_work_dir)
    // We want the generated `sql.gleam` module to be deterministic
    // on all operating systems, so we order all queries in a
    // predictable manner, since operating system calls to the file
    // system might return them in a different order.
    //
    |> list.sort(by: string.compare)
  use <- bool.guard(when: queries == [], return: Error(error.NoQueriesFound))

  let work_dir = sqlc.work_dir()
  use _ <- result.try(
    simplifile.create_directory_all(work_dir)
    |> result.map_error(error.FileError("create directory", work_dir, _)),
  )

  use binary <- result.try(sqlc_binary(config.sqlc))

  use schema <- result.try(case config.schema {
    config.FromFiles(path) -> Ok(from_work_dir(path))
    config.FromDatabase(connection_string) -> {
      io.println("\u{1F5C4} fetching schema...")
      let connection_string = database.connection_string(connection_string)
      use schema <- result.try(database.fetch_schema(
        config.engine,
        connection_string,
      ))
      use _ <- result.map(write(filepath.join(work_dir, "schema.sql"), schema))
      "schema.sql"
    }
  })

  let sqlc_json = sqlc.gen_sqlc_json(config.engine, schema, queries)
  use _ <- result.try(write(filepath.join(work_dir, "sqlc.json"), sqlc_json))

  io.println("\u{2728} generating gleam code...")

  use _ <- result.try(
    case sqlc.exec(binary, ["generate", "--file", "sqlc.json"]) {
      Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
      Ok(child_process.Output(status_code: _, output:)) ->
        Error(error.SqlcGenerateError(output))
      Error(e) ->
        Error(error.SqlcGenerateError(child_process.describe_start_error(e)))
    },
  )

  let output = from_root(config.output)
  use gen_result <- result.try(codegen.generate(
    filepath.join(work_dir, "queries.json"),
    output,
  ))

  io.println("\u{1F9F9} formatting generated code...")

  use _ <- result.try(
    case child_process.exec(run: "gleam", with: ["format", output], in: ".") {
      Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
      Ok(child_process.Output(status_code: _, output:)) ->
        Error(error.GleamFormatError(output))
      Error(e) ->
        Error(error.GleamFormatError(child_process.describe_start_error(e)))
    },
  )

  gen_result.unknown_types
  |> list.unique()
  |> list.each(fn(unknown) {
    io.println(cli.yellow("unknown column type: " <> unknown))
  })
  io.println("")

  Ok(Nil)
}

fn sqlc_binary(sqlc: config.Sqlc) -> Result(String, error.ParrotError) {
  case sqlc {
    config.Managed -> {
      io.println("\u{1F4E5} downloading sqlc binary...")
      use _ <- result.try(sqlc.download_binary())
      io.println("\u{1F50D} verifying sqlc binary...")
      let binary = sqlc.sqlc_binary_path()
      use _ <- result.map(sqlc.verify_binary(binary))
      binary
    }
    config.System ->
      child_process.find_executable("sqlc")
      |> result.replace_error(error.SqlcNotFound("`sqlc` is not in the PATH"))
      |> result.try(check_sqlc_version)
    config.Binary(path) -> check_sqlc_version(from_root(path))
  }
}

/// A binary parrot does not manage can be any version, so a different
/// version only results in a warning.
///
fn check_sqlc_version(binary: String) -> Result(String, error.ParrotError) {
  case sqlc.verify_binary(binary) {
    Ok(Nil) -> Ok(binary)
    Error(error.SqlcVersionError(e)) -> {
      io.println(cli.yellow("warning: " <> e))
      Ok(binary)
    }
    Error(e) -> Error(e)
  }
}

/// Paths in the config are relative to the project's root.
///
fn from_root(path: String) -> String {
  case filepath.is_absolute(path) {
    True -> path
    False -> filepath.join(project.root(), path)
  }
}

/// sqlc runs inside of `build/.parrot`, so paths given to it have to be
/// relative to that directory.
///
fn from_work_dir(path: String) -> String {
  case filepath.is_absolute(path), path {
    True, _ -> path
    False, "./" <> path | False, path -> filepath.join("../..", path)
  }
}

fn write(path: String, contents: String) -> Result(Nil, error.ParrotError) {
  simplifile.write(path, contents)
  |> result.map_error(error.FileError("write", path, _))
}
