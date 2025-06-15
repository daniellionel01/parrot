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
import parrot/internal/sqlc
import shellout
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

  let sqlc_dir = filepath.join(project.root(), "build/.parrot/")
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.yaml")
  let queries_file = filepath.join(sqlc_dir, "queries.json")

  let _ = simplifile.create_directory_all(sqlc_dir)

  let sqlc_yaml = sqlc.gen_sqlc_yaml(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_yaml)

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

  let gen_res =
    shellout.command(run: "sqlc", with: ["generate"], in: sqlc_dir, opt: [])
  use _ <- given.ok(gen_res, else_return: fn(err) {
    let #(_, err) = err
    Error(errors.SqlcGenerateError(err))
  })

  let project_name = project.project_name()
  let config =
    config.Config(
      gleam_module_out_path: project_name <> "/sql.gleam",
      json_file_path: queries_file,
    )
  let _ = codegen.codegen_from_config(config)

  Ok(Nil)
}
