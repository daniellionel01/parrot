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
import parrot/internal/error
import parrot/internal/project
import parrot/internal/shellout
import parrot/internal/sqlc
import simplifile

pub fn command_from_args() -> Result(cli.Command, error.ParrotError) {
  case argv.load().arguments {
    [] -> {
      cli.parse_env("DATABASE_URL")
      |> result.map(fn(a) {
        let #(engine, db) = a
        cli.Generate(engine:, db:)
      })
    }
    ["--env-var", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) {
        let #(engine, db) = a
        cli.Generate(engine:, db:)
      })
    }
    ["-e", env] -> {
      cli.parse_env(env)
      |> result.map(fn(a) {
        let #(engine, db) = a
        cli.Generate(engine:, db:)
      })
    }
    ["--sqlite", file_path] -> {
      Ok(cli.Generate(sqlc.SQLite, file_path))
    }
    ["help"] -> Ok(cli.Help)
    _ -> Ok(cli.Help)
  }
}

pub fn main() {
  case command_from_args() {
    Error(e) -> {
      let error_message = error.to_string(e)
      io.println(cli.red("Error: " <> error_message))
    }
    Ok(cmd) ->
      case cmd {
        cli.Help -> {
          io.println(cli.usage)
        }
        cli.Generate(engine:, db:) -> {
          let result = generate(engine, db)
          case result {
            Error(e) -> {
              io.println(cli.red("\nError: " <> error.to_string(e)))
            }
            Ok(_) -> {
              io.println("\u{1F99C} SQL successfully generated!")
            }
          }
        }
      }
  }
}

fn generate(engine: sqlc.Engine, db: String) -> Result(Nil, error.ParrotError) {
  let db = case db {
    "sqlite://" <> db -> db
    "sqlite:" <> db -> db
    db -> db
  }

  let files = project.walk(project.src())
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
    Error(_) -> io.println(cli.error_crossmark)
    Ok(_) -> Nil
  }

  io.println("\u{1F50D} verifying sqlc binary...")

  let _ = case sqlc.verify_binary() {
    Error(_) -> io.println(cli.error_crossmark)
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
      Error(error.SqlcGenerateError(error))
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
