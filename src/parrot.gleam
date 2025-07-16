import argv
import filepath
import given
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
      Ok(cli.Generate(cli.SQlite, file_path))
    }
    ["help"] -> Ok(cli.Usage)
    _ -> Ok(cli.Usage)
  }

  case cmd {
    Error(e) -> io.println(lib.red("Error: " <> e))
    Ok(cmd) ->
      case cmd {
        cli.Usage -> io.println(cli.usage)
        cli.Generate(engine:, db:) -> {
          let result = cmd_gen(engine, db)
          case result {
            Error(e) ->
              io.println(lib.red("Error: " <> errors.err_to_string(e)))
            Ok(_) -> io.println(lib.green("SQL successfully generated!"))
          }
        }
      }
  }
}

fn cmd_gen(engine: cli.Engine, db: String) -> Result(Nil, errors.ParrotError) {
  let files = lib.walk(project.src())
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

  let sqlc_binary = sqlc.sqlc_binary_path()
  let sqlc_dir = filepath.directory_name(sqlc_binary)
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.yaml")
  let queries_file = filepath.join(sqlc_dir, "queries.json")

  let _ = simplifile.create_directory_all(sqlc_dir)

  let spinner =
    spinner.new("downloading sqlc binary")
    |> spinner.start()

  let download_res = sqlc.download_binary()
  case download_res {
    Error(_) -> spinner.complete_current(spinner, spinner.orange_warning())
    Ok(_) -> spinner.complete_current(spinner, spinner.green_checkmark())
  }
  let spinner =
    spinner.new("verifying sqlc binary")
    |> spinner.start()

  let verify_res = sqlc.verify_binary()
  case verify_res {
    Error(_) -> spinner.complete_current(spinner, spinner.orange_warning())
    Ok(_) -> spinner.complete_current(spinner, spinner.green_checkmark())
  }

  let sqlc_yaml = sqlc.gen_sqlc_yaml(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_yaml)

  let spinner =
    spinner.new("fetching schema")
    |> spinner.start()

  use schema_sql <- result.try(case engine {
    cli.MySQL -> {
      use schema <- result.try(db.fetch_schema_mysql(db))
      Ok(schema)
    }
    cli.PostgreSQL -> {
      use schema <- result.try(db.fetch_schema_postgresql(db))
      Ok(schema)
    }
    cli.SQlite -> {
      use schema <- result.try(db.fetch_schema_sqlite(db))
      let sql =
        schema
        |> list.map(string.trim)
        |> list.map(fn(sql) { sql <> ";" })
        |> string.join("\n")
      Ok(sql)
    }
  })
  let _ = simplifile.write(schema_file, schema_sql)

  spinner.complete_current(spinner, spinner.green_checkmark())

  let spinner =
    spinner.new("generating gleam code")
    |> spinner.start()

  let gen_attempt =
    shellout.command(run: "./sqlc", with: ["generate"], in: sqlc_dir, opt: [])
  let gen_attempt = case gen_attempt {
    Error(_) -> {
      shellout.command(run: "sqlc", with: ["generate"], in: sqlc_dir, opt: [])
    }
    Ok(val) -> Ok(val)
  }
  use _ <- given.ok(gen_attempt, else_return: fn(err) {
    let #(_, err) = err
    Error(errors.SqlcGenerateError(err))
  })

  let project_name = project.project_name()
  let config =
    config.Config(
      gleam_module_out_path: project_name <> "/sql.gleam",
      json_file_path: queries_file,
    )
  let gen_result = codegen.codegen_from_config(config)
  use gen_result <- given.ok(gen_result, else_return: fn(_) {
    Error(errors.CodegenError)
  })

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
  use _ <- given.ok(stdout_format, else_return: fn(err) {
    let #(_, err) = err
    Error(errors.GleamFormatError(err))
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
