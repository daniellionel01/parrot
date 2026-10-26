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
  let #(text, status_code) = case cli.command_from_args() {
    Ok(cli.Help) -> {
      #(cli.usage_text, 0)
    }
    Ok(cli.Generate(engine:, db:)) -> {
      let result = generate(engine, db)
      case result {
        Ok(_) -> {
          #("\u{1F99C} SQL successfully generated!", 0)
        }
        Error(e) -> {
          let error_message = error.to_string(e)
          #(cli.red("\nError: " <> error_message), 1)
        }
      }
    }
    Error(e) -> {
      let error_message = error.to_string(e)
      #(cli.red("Error: " <> error_message), 1)
    }
  }

  io.println(text)
  exit(status_code)
}

/// exit(0) -> success
/// exit(1) -> failure
///
@external(erlang, "parrot_ffi", "exit")
fn exit(n: Int) -> Nil

fn generate(
  engine: sqlc.Engine,
  connection_string: String,
) -> Result(Nil, error.ParrotError) {
  let connection_string = database.connection_string(connection_string)

  use files <- result.try(project.walk(project.src()))
  let queries =
    files
    |> dict.to_list
    |> list.map(fn(file) {
      let #(_, files) = file
      list.map(files, fn(file) {
        let file = case file {
          "./" <> rest -> rest
          x -> x
        }
        filepath.join("../..", file)
      })
    })
    |> list.flatten()
    // We want the generated `sql.gleam` module to be deterministic
    // on all operating systems, so we order all queries in a
    // predictable manner, since operating system calls to the file
    // system might return them in a different order.
    //
    |> list.sort(by: string.compare)
  use <- bool.guard(when: queries == [], return: Error(error.NoQueriesFound))

  let sqlc_binary = sqlc.sqlc_binary_path()
  let sqlc_dir = filepath.directory_name(sqlc_binary)
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.json")
  let queries_file = filepath.join(sqlc_dir, "queries.json")
  use _ <- result.try(
    simplifile.create_directory_all(sqlc_dir)
    |> result.map_error(error.FileError("create directory", sqlc_dir, _)),
  )

  io.println("\u{1F4E5} downloading sqlc binary...")
  use _ <- result.try(sqlc.download_binary())

  io.println("\u{1F50D} verifying sqlc binary...")
  use _ <- result.try(sqlc.verify_binary())

  let sqlc_json = sqlc.gen_sqlc_json(engine, queries)
  use _ <- result.try(write(sqlc_file, sqlc_json))

  io.println("\u{1F5C4} fetching schema...")

  use schema_sql <- result.try(database.fetch_schema(engine, connection_string))
  use _ <- result.try(write(schema_file, schema_sql))

  io.println("\u{2728} generating gleam code...")

  let gen_result = sqlc.exec(["generate", "--file", "sqlc.json"])

  use _ <- result.try(case gen_result {
    Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
    Ok(child_process.Output(status_code: _, output:)) -> {
      Error(error.SqlcGenerateError(output))
    }
    Error(error) -> {
      let error = child_process.describe_start_error(error)
      Error(error.SqlcGenerateError(error))
    }
  })

  use config <- result.try(config.load(queries_file))
  use gen_result <- result.try(codegen.from_config(config))

  io.println("\u{1F9F9} formatting generated code...")

  let output_path = config.output_module_path(config)
  let stdout_format =
    child_process.exec(
      run: "gleam",
      with: ["format", output_path],
      in: project.root(),
    )
  use _ <- result.try(case stdout_format {
    Ok(child_process.Output(status_code: 0, output: _)) -> Ok(Nil)
    Ok(child_process.Output(status_code: _, output:)) -> {
      Error(error.GleamFormatError(output))
    }
    Error(error) -> {
      let error = child_process.describe_start_error(error)
      Error(error.GleamFormatError(error))
    }
  })

  gen_result.unknown_types
  |> list.unique()
  |> list.each(fn(unknown) {
    io.println(cli.yellow("unknown column type: " <> unknown))
  })
  io.println("")

  Ok(Nil)
}

fn write(path: String, contents: String) -> Result(Nil, error.ParrotError) {
  simplifile.write(path, contents)
  |> result.map_error(error.FileError("write", path, _))
}
