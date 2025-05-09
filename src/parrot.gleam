import argv
import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import parrot/codegen
import parrot/config
import parrot/internal/project
import shellout
import simplifile
import sqlight

const usage = "Usage:
  gleam run -m parrot help
  gleam run -m parrot gen [sqlite | mysql | postgresql] [database]
"

pub type Engine {
  SQlite
  MySQL
  PostgreSQL
}

fn engine_decoder() -> decode.Decoder(Engine) {
  use variant <- decode.then(decode.string)
  case variant {
    "sqlite" -> decode.success(SQlite)
    "mysql" -> decode.success(MySQL)
    "postgresql" -> decode.success(PostgreSQL)
    _ -> decode.failure(SQlite, "Driver")
  }
}

pub fn engine_to_string(engine: Engine) {
  case engine {
    MySQL -> "mysql"
    PostgreSQL -> "postgresql"
    SQlite -> "sqlite"
  }
}

pub fn main() -> Result(Nil, String) {
  case argv.load().arguments {
    ["gen", engine_arg, db] -> {
      let engine = decode.run(dynamic.from(engine_arg), engine_decoder())
      let _ = case engine {
        Error(_) -> {
          io.println_error("Could not determine engine: " <> engine_arg)
          Ok(Nil)
        }
        Ok(engine) -> {
          let _ = cmd_gen(engine, db)
          Ok(Nil)
        }
      }
      Ok(Nil)
    }
    ["help"] -> {
      io.println(usage)
      Ok(Nil)
    }
    _ -> {
      io.println(usage)
      Ok(Nil)
    }
  }
}

pub fn cmd_gen(engine: Engine, db: String) {
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

  let sqlc_dir = filepath.join(project.root(), "build/.parrot/")
  let schema_file = filepath.join(sqlc_dir, "schema.sql")
  let sqlc_file = filepath.join(sqlc_dir, "sqlc.yaml")
  let queries_file = filepath.join(sqlc_dir, "queries.json")

  let _ = simplifile.create_directory_all(sqlc_dir)

  let sqlc_yaml = gen_sqlc_yaml(engine, queries)
  let _ = simplifile.write(sqlc_file, sqlc_yaml)

  let assert Ok(schema_sql) = case engine {
    MySQL -> todo
    PostgreSQL -> {
      use schema <- result.try(
        fetch_schema_postgresql(db) |> result.map_error(fn(_) { Error("") }),
      )
      Ok(schema)
    }
    SQlite -> {
      use schema <- result.try(
        fetch_schema_sqlite(db) |> result.map_error(fn(_) { Error("") }),
      )
      let sql =
        schema
        |> list.map(string.trim)
        |> list.map(fn(sql) { sql <> ";" })
        |> string.join("\n")
      Ok(sql)
    }
  }
  let _ = simplifile.write(schema_file, schema_sql)

  let _ =
    shellout.command(run: "sqlc", with: ["generate"], in: sqlc_dir, opt: [])

  let config =
    config.Config(
      gleam_module_out_path: "parrots/sql.gleam",
      json_file_path: queries_file,
    )
  Ok(codegen.codegen_from_config(config))
}

pub fn fetch_schema_postgresql(db: String) {
  shellout.command(
    run: "pg_dump",
    with: [
      "--no-privileges",
      "--no-acl",
      "--no-owner",
      "--schema-only",
      "--no-comments",
      "--encoding=utf8",
      db,
    ],
    in: ".",
    opt: [],
  )
}

pub fn fetch_schema_sqlite(db: String) {
  use conn <- sqlight.with_connection(db)

  let schema_decoder = {
    use sql <- decode.field(0, decode.string)
    decode.success(sql)
  }

  let sql =
    "
SELECT sql
  FROM sqlite_master
  WHERE type IN ('table', 'view', 'index', 'trigger')
    AND name NOT LIKE 'sqlite_%'
    AND sql IS NOT NULL
  ORDER BY
      CASE type
          WHEN 'table' THEN 1
          WHEN 'view' THEN 2
          WHEN 'index' THEN 3
          WHEN 'trigger' THEN 4
          ELSE 5
      END,
      name;
  "
  sqlight.query(sql, on: conn, with: [], expecting: schema_decoder)
}

pub fn gen_sqlc_yaml(engine: Engine, queries: List(String)) {
  let result = "
version: \"2\"
plugins:
  - name: jsonb
    wasm:
      url: https://github.com/daniellionel01/sqlc-gen-json/releases/download/v1.0.0/sqlc-gen-json.wasm
      sha256: 5d48e462aa8db371be5c9ce89a7494ad8e3baf5112e78386091313afd6930061
sql:
  - schema: schema.sql
    queries: [" <> string.join(queries, ", ") <> "]
    engine: " <> engine_to_string(engine) <> "
    codegen:
      - out: .
        plugin: jsonb
        options:
          indent: \"  \"
          filename: queries.json
  "

  string.trim(result)
}

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn walk(from: String) -> Dict(String, List(String)) {
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
