import argv
import glint
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

fn sqlite_flag() -> glint.Flag(String) {
  glint.string_flag(named: "sqlite")
  |> glint.flag_help("path to an SQLite database")
}

fn env_var_flag() -> glint.Flag(String) {
  glint.string_flag(named: "env-var")
  |> glint.flag_help("environment variable to use instead of `DATABASE_URL`")
}

fn sqlc_flag() -> glint.Flag(String) {
  glint.string_flag(named: "sqlc")
  |> glint.flag_help("path to `sqlc` binary")
}

fn cmd(
  no_args no_args: Bool,
) -> glint.Command(Nil) {
  use <- glint.command_help("")

  use sqlite <- glint.flag(sqlite_flag())
  use env_var <- glint.flag(env_var_flag())
  use sqlc <- glint.flag(sqlc_flag())

  use _, _, flags <- glint.command()

  let sqlite = sqlite(flags) |> result.replace_error(Nil)
  let env_var = env_var(flags) |> result.replace_error(Nil)
  let sqlc = sqlc(flags) |> result.replace_error(Nil)

  case build_gen(sqlite:, env_var:), no_args {
    Error(_), True ->
      io.println(cli.usage)

    Error(err), False ->
      io.println(lib.red("\nError: " <> err))

    Ok(cli.Usage), _ ->
      io.println(cli.usage)

    Ok(cli.Generate(engine:, db:)), _ ->
      case cmd_gen(engine, db, sqlc) {
        Error(err) ->
          io.println(lib.red("\nError: " <> errors.err_to_string(err)))
        Ok(_) ->
          io.println(lib.green("SQL successfully generated!"))
      }
  }
}

fn build_gen(
  sqlite sqlite: Result(String, Nil),
  env_var env_var: Result(String, Nil),
) -> Result(cli.Command, String) {
  result.or(
    build_gen_sqlite(sqlite),
    build_gen_non_sqlite(env_var),
  )
}

fn build_gen_sqlite(
  sqlite sqlite: Result(String, Nil),
) -> Result(cli.Command, String) {
  sqlite
  |> result.map(fn(file_path) {
    cli.Generate(sqlc.SQLite, file_path)
  })
  |> result.replace_error("no `sqlite` flag")
}

fn build_gen_non_sqlite(
  env_var env_var: Result(String, Nil),
) -> Result(cli.Command, String) {
  let env_var =
    env_var
    |> result.unwrap("DATABASE_URL")

  cli.parse_env(env_var)
  |> result.map(fn(a) { cli.Generate(a.0, a.1) })
}

fn help_cmd() -> glint.Command(Nil) {
  use _, _, _ <- glint.command()

  io.println(cli.usage)
}

pub fn main() {
  let args = argv.load().arguments

  glint.new()
  |> glint.add(at: [], do: cmd(no_args: args |> list.is_empty))
  |> glint.add(at: ["help"], do: help_cmd())
  |> glint.run(args)
}

fn cmd_gen(
  engine: sqlc.Engine,
  db: String,
  sqlc_override: Result(String, Nil),
) -> Result(Nil, errors.ParrotError) {
  let db = case db {
    "sqlite://" <> db -> db
    "sqlite:" <> db -> db
    db -> db
  }

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
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.json")
  let queries_file = filepath.join(sqlc_dir, "queries.json")
  let _ = simplifile.create_directory_all(sqlc_dir)

  case sqlc_override {
    Ok(_) -> Nil

    Error(Nil) -> {
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

      Nil
    }
  }

  let sqlc_json = sqlc.gen_sqlc_json(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_json)

  let spinner =
    spinner.new("fetching schema")
    |> spinner.start()

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

  spinner.complete_current(spinner, spinner.green_checkmark())

  let spinner =
    spinner.new("generating gleam code")
    |> spinner.start()

  let sqlc_path =
    sqlc_override
    |> result.unwrap("./sqlc")

  let gen_result =
    shellout.command(
      run: sqlc_path,
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
