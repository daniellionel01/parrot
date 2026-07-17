import argv
import filepath
import gleam/bool
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import parrot/internal/cli
import parrot/internal/codegen
import parrot/internal/config
import parrot/internal/db
import parrot/internal/errors
import parrot/internal/project
import parrot/internal/shellout
import parrot/internal/sqlc
import simplifile

pub fn main() {
  let cmd: Result(cli.Command, String) = case argv.load().arguments {
    [] -> {
      cli.parse_env("DATABASE_URL")
      |> result.map(fn(a) { cli.Generate(a.0, a.1) })
    }
    ["--env-var", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) { cli.Generate(a.0, a.1) })
    }
    ["-e", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) { cli.Generate(a.0, a.1) })
    }
    ["--sqlite", file_path] -> {
      Ok(cli.Generate(sqlc.SQLite, file_path))
    }
    ["help"] -> Ok(cli.Usage)
    _ -> Ok(cli.Usage)
  }

  case cmd {
    Error(e) -> io.println(cli.red("Error: " <> e))
    Ok(cmd) ->
      case cmd {
        cli.Usage -> io.println(cli.usage)
        cli.Generate(engine:, db:) -> {
          let result = cmd_gen(engine, db)
          case result {
            Error(e) ->
              io.println(cli.red("\nError: " <> errors.err_to_string(e)))
            Ok(_) -> io.println("\u{1F99C} SQL successfully generated!")
          }
        }
      }
  }
}

fn print_error() {
  io.println("\u{274C}")
}

fn cmd_gen(engine: sqlc.Engine, db: String) -> Result(Nil, errors.ParrotError) {
  let db = case db {
    "sqlite://" <> db -> db
    "sqlite:" <> db -> db
    db -> db
  }

  let files = walk(project.src())
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

  let sqlc_binary = sqlc.sqlc_binary_path()
  let sqlc_dir = filepath.directory_name(sqlc_binary)
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.json")
  let queries_file = filepath.join(sqlc_dir, "queries.json")
  let _ = simplifile.create_directory_all(sqlc_dir)

  io.println("\u{1F4E5} downloading sqlc binary...")
  let _ = case sqlc.download_binary() {
    Error(_) -> print_error()
    Ok(_) -> Nil
  }

  io.println("\u{1F50D} verifying sqlc binary...")

  let _ = case sqlc.verify_binary() {
    Error(_) -> print_error()
    Ok(_) -> Nil
  }

  let sqlc_json = sqlc.gen_sqlc_json(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_json)

  io.println("\u{1F5C4} fetching schema...")

  use schema_sql <- result.try(case engine {
    sqlc.MySQL -> {
      use schema <- result.try(db.fetch_schema_mysql(db))
      Ok(schema)
    }
    sqlc.PostgreSQL -> {
      use schema <- result.try(db.fetch_schema_postgresql(db))

      // this is an edge case with the postgres schema dump.
      // sqlc does not like those lines from postgres 17.
      let schema =
        schema
        |> string.split("\n")
        |> list.filter(fn(line) {
          !string.starts_with(line, "\\restrict")
          && !string.starts_with(line, "\\unrestrict")
        })
        |> string.join("\n")

      Ok(schema)
    }
    sqlc.SQLite -> {
      use schema <- result.try(db.fetch_schema_sqlite(db))
      let sql = string.trim(schema)
      Ok(sql)
    }
  })
  let _ = simplifile.write(schema_file, schema_sql)

  io.println("\u{2728} generating gleam code...")

  let gen_result =
    shellout.command(
      run: "./sqlc",
      with: ["generate", "--file", "sqlc.json"],
      in: sqlc_dir,
      opt: [],
    )

  use _ <- result.try(case gen_result {
    Ok(_) -> Ok(Nil)
    Error(error) -> {
      let #(_, error) = error
      Error(errors.SqlcGenerateError(error))
    }
  })

  let project_name = project.project_name()
  let config =
    config.Config(
      gleam_module_out_path: project_name <> "/sql.gleam",
      json_file_path: queries_file,
    )
  use gen_result <- result.try(codegen.codegen_from_config(config))

  io.println("\u{1F9F9} formatting generated code...")

  let output_path = filepath.join(project.src(), project_name <> "/sql.gleam")

  let stdout_format =
    shellout.command(
      run: "gleam",
      with: ["format", output_path],
      in: project.root(),
      opt: [],
    )
  use _ <- result.try(case stdout_format {
    Ok(_) -> Ok(Nil)
    Error(error) -> {
      let #(_, error) = error
      Error(errors.GleamFormatError(error))
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

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
fn walk(from: String) -> dict.Dict(String, List(String)) {
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
