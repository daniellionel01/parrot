import argv
import filepath
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
import parrot/internal/lib
import parrot/internal/project
import parrot/internal/shellout
import parrot/internal/spinner
import parrot/internal/sqlc
import simplifile

pub fn main() {
  let cmd: Result(cli.Command, String) = case argv.load().arguments {
    [] -> {
      cli.parse_env("DATABASE_URL")
      |> result.map(fn(a) { cli.Generate(a.0, cli.Database(a.1)) })
    }
    ["--env-var", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) { cli.Generate(a.0, cli.Database(a.1)) })
    }
    ["-e", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) { cli.Generate(a.0, cli.Database(a.1)) })
    }
    ["--sqlite", file_path] -> {
      Ok(cli.Generate(sqlc.SQLite, cli.Database(file_path)))
    }
    ["--schema", engine_specifier, path_to_schema] -> {
      let engine = 
        engine_specifier 
        |> string.lowercase
        |> cli.engine_from_env
      case engine {
        Error(e) -> Error(errors.err_to_string(e))
        Ok(engine) -> {
          case filepath.expand(path_to_schema) {
            Ok(expanded_path) -> Ok(cli.Generate(engine, cli.SQLFile(expanded_path)))
            Error(_) -> Error(errors.err_to_string(errors.SchemaFileError))
          }
        }
      }
    }
    ["help"] -> Ok(cli.Usage)
    _ -> Ok(cli.Usage)
  }

  case cmd {
    Error(e) -> io.println(lib.red("Error: " <> e))
    Ok(cmd) ->
      case cmd {
        cli.Usage -> io.println(cli.usage)
        cli.Generate(engine:, schema:) -> {
          let result = cmd_gen(engine, schema)
          case result {
            Error(e) ->
              io.println(lib.red("\nError: " <> errors.err_to_string(e)))
            Ok(_) -> io.println(lib.green("SQL successfully generated!"))
          }
        }
      }
  }
}

fn cmd_gen(engine: sqlc.Engine, schema_source: cli.SchemaSource) -> Result(Nil, errors.ParrotError) {

  let assert Ok(files) = lib.walk(project.src())
  let queries = case schema_source {
    cli.Database(_) -> files
    cli.SQLFile(path) -> list.filter_map(files, fn(f) {
      case f == path {
        True -> Error(Nil)
        False -> Ok(f)
      }
    })
  } |> list.map(fn(file) {
    filepath.join("../..", file)
  })

  let sqlc_binary = sqlc.sqlc_binary_path()
  let sqlc_dir = filepath.directory_name(sqlc_binary)
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.json")
  let queries_file = filepath.join(sqlc_dir, "queries.json")
  let _ = simplifile.create_directory_all(sqlc_dir)

  let spinner =
    spinner.new("downloading sqlc binary")
    |> spinner.start()

  let _ = case sqlc.download_binary() {
    Error(_) -> spinner.complete_current(spinner, spinner.orange_warning())
    Ok(_) -> spinner.complete_current(spinner, spinner.green_checkmark())
  }

  let spinner =
    spinner.new("verifying sqlc binary")
    |> spinner.start()

  let _ = case sqlc.verify_binary() {
    Error(_) -> spinner.complete_current(spinner, spinner.orange_warning())
    Ok(_) -> spinner.complete_current(spinner, spinner.green_checkmark())
  }

  let sqlc_json = sqlc.gen_sqlc_json(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_json)

  let spinner =
    spinner.new("fetching schema")
    |> spinner.start()

  use schema_sql <- result.try(case schema_source {
    cli.Database(url) -> {
      let db = case url {
        "sqlite://" <> db -> db
        "sqlite:" <> db -> db
        db -> db
      }

      case engine {
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
      }
    }
    cli.SQLFile(path) -> {
      case simplifile.read(path) {
        Ok(content) -> Ok(string.trim(content))
        Error(_) -> Error(errors.SchemaFileError)
      }
    }
  })

  let _ = simplifile.write(schema_file, schema_sql)
  spinner.complete_current(spinner, spinner.green_checkmark())

  let spinner =
    spinner.new("generating gleam code")
    |> spinner.start()

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
  let gen_result = codegen.codegen_from_config(config)
  use gen_result <- result.try(result.replace_error(
    gen_result,
    errors.CodegenError,
  ))

  spinner.complete_current(spinner, spinner.green_checkmark())

  let spinner =
    spinner.new("formatting generated code")
    |> spinner.start()

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

  spinner.complete_current(spinner, spinner.green_checkmark())

  gen_result.unknown_types
  |> list.unique()
  |> list.each(fn(unknown) {
    io.println(lib.yellow("unknown column type: " <> unknown))
  })
  io.println("")

  Ok(Nil)
}
