//// This module generates the JSON config, which is used when running sqlc, and
//// decodes the JSON that sqlc generates.

import filepath
import given
import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, Some}
import gleam/result
import gleam/set
import gleam/string
import parrot/internal/errors
import parrot/internal/project
import parrot/internal/shellout
import simplifile.{Execute, FilePermissions, Read, Write}

pub type Engine {
  SQLite
  MySQL
  PostgreSQL
}

type Queries {
  QueriesSingle(String)
  QueriesMultiple(List(String))
}

type GenJson {
  GenJson(out: Option(String), indent: Option(String), filename: Option(String))
}

type Gen {
  Gen(json: Option(GenJson))
}

type Sql {
  Sql(
    schema: Option(String),
    queries: Option(Queries),
    engine: Engine,
    gen: Option(Gen),
  )
}

type Version2 {
  Version2
}

type Config {
  Config(version: Version2, sql: List(Sql))
}

fn queries_to_json(queries: Queries) -> json.Json {
  case queries {
    QueriesSingle(query) -> json.string(query)
    QueriesMultiple(queries) -> json.array(queries, json.string)
  }
}

fn engine_to_json(engine: Engine) -> json.Json {
  let engine = case engine {
    SQLite -> "sqlite"
    MySQL -> "mysql"
    PostgreSQL -> "postgresql"
  }
  json.string(engine)
}

fn gen_json_to_json(gen_json: GenJson) -> json.Json {
  let GenJson(out:, indent:, filename:) = gen_json
  let json_object = case out {
    option.None -> []
    option.Some(out) -> [#("out", json.string(out))]
  }
  let json_object = case indent {
    option.None -> json_object
    option.Some(indent) -> [#("indent", json.string(indent)), ..json_object]
  }
  let json_object = case filename {
    option.None -> json_object
    option.Some(filename) -> [
      #("filename", json.string(filename)),
      ..json_object
    ]
  }
  json.object(json_object)
}

fn sql_to_json(sql: Sql) -> json.Json {
  let Sql(schema:, queries:, engine:, gen:) = sql
  let json_object = [#("engine", engine_to_json(engine))]
  let json_object = case schema {
    option.None -> json_object
    option.Some(schema) -> [#("schema", json.string(schema)), ..json_object]
  }
  let json_object = case queries {
    option.None -> json_object
    option.Some(queries) -> [
      #("queries", queries_to_json(queries)),
      ..json_object
    ]
  }
  let json_object = case gen {
    option.None -> json_object
    option.Some(gen) -> [#("gen", gen_to_json(gen)), ..json_object]
  }
  json.object(json_object)
}

fn gen_to_json(gen: Gen) -> json.Json {
  let Gen(json:) = gen
  let json_object = case json {
    option.None -> []
    option.Some(json) -> [#("json", gen_json_to_json(json))]
  }
  json.object(json_object)
}

fn version2_to_json(_: Version2) -> json.Json {
  json.string("2")
}

fn config_to_json(config: Config) -> json.Json {
  case config {
    Config(version:, sql:) ->
      json.object([
        #("version", version2_to_json(version)),
        #("sql", json.array(sql, sql_to_json)),
      ])
  }
}

fn config_to_json_string(config: Config) -> String {
  config_to_json(config) |> json.to_string
}

pub type TypeRef {
  TypeRef(catalog: String, schema: String, name: String)
}

pub type TableColumn {
  TableColumn(
    name: String,
    not_null: Bool,
    is_array: Bool,
    comment: String,
    length: Int,
    is_named_param: Bool,
    is_func_call: Bool,
    scope: String,
    table_alias: String,
    is_sqlc_slice: Bool,
    original_name: String,
    unsigned: Bool,
    array_dims: Int,
    table: Option(TableRef),
    type_ref: TypeRef,
  )
}

pub type TableRef {
  TableRef(catalog: String, schema: String, name: String)
}

pub type Table {
  Table(rel: TableRef, comment: String, columns: List(TableColumn))
}

pub type Schema {
  Schema(comment: String, name: String, tables: List(Table), enums: List(Enum))
}

pub type Enum {
  Enum(name: String, vals: List(String), comment: String)
}

pub type Catalog {
  Catalog(
    comment: String,
    default_schema: String,
    name: String,
    schemas: List(Schema),
  )
}

pub type QueryCmd {
  One
  Many
  Exec
  ExecResult
  ExecRows
  ExecLastId
  BatchExec
  BatchMany
  BatchOne
  CopyFrom
}

pub fn query_cmd_to_string(query_cmd: QueryCmd) -> String {
  case query_cmd {
    One -> "one"
    Many -> "many"
    Exec -> "exec"
    ExecResult -> "exec_result"
    ExecRows -> "exec_rows"
    ExecLastId -> "exec_last_id"
    BatchExec -> "batch_exec"
    BatchMany -> "batch_many"
    BatchOne -> "batch_one"
    CopyFrom -> "copy_from"
  }
}

pub type QueryParam {
  QueryParam(number: Int, column: TableColumn)
}

pub type Query {
  Query(
    text: String,
    name: String,
    cmd: QueryCmd,
    filename: String,
    columns: List(TableColumn),
    insert_into_table: Option(TableRef),
    comments: List(String),
    params: List(QueryParam),
  )
}

pub type SQLC {
  SQLC(
    sqlc_version: String,
    plugin_options: String,
    global_options: String,
    catalog: Catalog,
    queries: List(Query),
  )
}

pub fn decode_sqlc(data: dynamic.Dynamic) {
  let table_ref_decoder = {
    use name <- decode.field("name", decode.string)
    use schema <- decode.field("schema", decode.string)
    use catalog <- decode.field("catalog", decode.string)
    decode.success(TableRef(catalog, schema, name))
  }

  let type_ref_decoder = {
    use schema <- decode.field("schema", decode.string)
    use catalog <- decode.field("catalog", decode.string)
    use name <- decode.field("name", decode.string)
    decode.success(TypeRef(catalog, schema, name))
  }

  let table_col_decoder = {
    use name <- decode.field("name", decode.string)
    use not_null <- decode.field("not_null", decode.bool)
    use is_array <- decode.field("is_array", decode.bool)
    use comment <- decode.field("comment", decode.string)
    use length <- decode.field("length", decode.int)
    use is_named_param <- decode.field("is_named_param", decode.bool)
    use is_func_call <- decode.field("is_func_call", decode.bool)
    use scope <- decode.field("scope", decode.string)
    use table_alias <- decode.field("table_alias", decode.string)
    use is_sqlc_slice <- decode.field("is_sqlc_slice", decode.bool)
    use original_name <- decode.field("original_name", decode.string)
    use unsigned <- decode.field("unsigned", decode.bool)
    use array_dims <- decode.field("array_dims", decode.int)
    use table <- decode.field("table", decode.optional(table_ref_decoder))
    use type_ref <- decode.field("type", type_ref_decoder)

    TableColumn(
      name,
      not_null,
      is_array,
      comment,
      length,
      is_named_param,
      is_func_call,
      scope,
      table_alias,
      is_sqlc_slice,
      original_name,
      unsigned,
      array_dims,
      table,
      type_ref,
    )
    |> decode.success()
  }

  let table_decoder = {
    use rel <- decode.field("rel", table_ref_decoder)
    use comment <- decode.field("comment", decode.string)
    use columns <- decode.field("columns", decode.list(table_col_decoder))
    decode.success(Table(rel, comment, columns))
  }

  let enum_decoder = {
    use name <- decode.field("name", decode.string)
    use vals <- decode.field("vals", decode.list(decode.string))
    use comment <- decode.field("comment", decode.string)
    decode.success(Enum(name, vals, comment))
  }

  let schema_decoder = {
    use comment <- decode.field("comment", decode.string)
    use name <- decode.field("name", decode.string)
    use tables <- decode.field("tables", decode.list(table_decoder))
    use enums <- decode.field("enums", decode.list(enum_decoder))
    decode.success(Schema(comment, name, tables, enums))
  }

  let catalog_decoder = {
    use comment <- decode.field("comment", decode.string)
    use default_schema <- decode.field("default_schema", decode.string)
    use name <- decode.field("name", decode.string)
    use schemas <- decode.field("schemas", decode.list(schema_decoder))
    decode.success(Catalog(comment, default_schema, name, schemas))
  }

  let params_decoder = {
    use number <- decode.field("number", decode.int)
    use column <- decode.field("column", table_col_decoder)
    decode.success(QueryParam(number, column))
  }

  let cmd_decoder = {
    use cmd <- decode.then(decode.string)
    case cmd {
      ":one" -> decode.success(One)
      ":many" -> decode.success(Many)
      ":exec" -> decode.success(ExecResult)
      ":execresult" -> decode.success(ExecResult)
      ":execrows" -> decode.success(ExecRows)
      ":execlastid" -> decode.success(ExecLastId)
      ":batchexec" -> decode.success(BatchExec)
      ":batchmany" -> decode.success(BatchMany)
      ":batchone" -> decode.success(BatchOne)
      ":copyfrom" -> decode.success(CopyFrom)
      _ -> decode.failure(One, "QueryCmd")
    }
  }

  let query_decoder = {
    use text <- decode.field("text", decode.string)
    use name <- decode.field("name", decode.string)
    use cmd <- decode.field("cmd", cmd_decoder)
    use filename <- decode.field("filename", decode.string)
    use columns <- decode.field("columns", decode.list(table_col_decoder))
    use insert_into_table <- decode.field(
      "insert_into_table",
      decode.optional(table_ref_decoder),
    )
    use comments <- decode.field("comments", decode.list(decode.string))
    use params <- decode.field("params", decode.list(params_decoder))

    Query(
      text,
      name,
      cmd,
      filename,
      columns,
      insert_into_table,
      comments,
      params,
    )
    |> decode.success()
  }

  let decoder = {
    use sqlc_version <- decode.field("sqlc_version", decode.string)
    use plugin_options <- decode.field("plugin_options", decode.string)
    use global_options <- decode.field("global_options", decode.string)
    use catalog <- decode.field("catalog", catalog_decoder)
    use queries <- decode.field("queries", decode.list(query_decoder))

    SQLC(sqlc_version, plugin_options, global_options, catalog, queries)
    |> decode.success()
  }

  decode.run(data, decoder)
}

pub fn gen_sqlc_json(engine: Engine, queries: List(String)) -> String {
  let config =
    Config(version: Version2, sql: [
      Sql(
        schema: Some("schema.sql"),
        queries: Some(QueriesMultiple(queries)),
        engine:,
        gen: Some(
          Gen(
            json: Some(GenJson(
              out: Some("."),
              indent: Some("  "),
              filename: Some("queries.json"),
            )),
          ),
        ),
      ),
    ])
  config_to_json_string(config)
}

pub fn sqlc_binary_path() {
  filepath.join(project.root(), "build/.parrot/sqlc")
}

fn binary_exists(path) {
  case simplifile.is_file(path) {
    Ok(True) -> True
    Ok(False) | Error(_) -> False
  }
}

const sqlc_version = "1.30.0"

fn get_download_path_and_hash() -> Result(#(String, String), errors.ParrotError) {
  let base = "https://downloads.sqlc.dev/sqlc_" <> sqlc_version

  let os = get_os()
  let cpu = get_cpu()

  let platform = case os, cpu {
    "darwin", "arm64" | "darwin", "aarch64" ->
      Ok(#(
        "_darwin_arm64.tar.gz",
        "d8e6153c9a6c74fa178abc4465c13ac008c06d64f50720c4b7c7203f98c8cfc6",
      ))

    "darwin", "amd64" | "darwin", "x86_64" | "darwin", "x64" ->
      Ok(#(
        "_darwin_amd64.tar.gz",
        "7473103d9148b218a57e15a53b562c285c916fdedd85f6053ce9feaa714dcfd5",
      ))

    "linux", "arm64" | "linux", "aarch64" ->
      Ok(#(
        "_linux_arm64.tar.gz",
        "845fb31828129f3ecd3442f24e3ac0e8b1188660bf6807b8c652bd7acece0af7",
      ))

    "linux", "amd64" | "linux", "x86_64" | "linux", "x64" ->
      Ok(#(
        "_linux_amd64.tar.gz",
        "e47db21025595d7e77b1260b2f97b6793401a4cba047d42e635c347e8443b5f4",
      ))

    "win32", "amd64" | "win32", "x86_64" | "win32", "x64" ->
      Ok(#(
        "_windows_amd64.tar.gz",
        "3fd5852bb05bd77d2bf4184984784844b55c1aa1f64ed69099d5fc528a10307e",
      ))

    _, _ -> Error(Nil)
  }

  use #(platform, hash) <- given.ok(platform, else_return: fn(_) {
    Error(errors.SqlcDownloadError(
      "unsupported platform: " <> os <> ", " <> cpu,
    ))
  })

  Ok(#(base <> platform, hash))
}

fn check_sqlc_integrity(bin: BitArray, expected_hash: String) {
  let hash = crypto.hash(crypto.Sha256, bin)
  let hash_string = bit_array.base16_encode(hash)
  case string.lowercase(hash_string) == string.lowercase(expected_hash) {
    True -> Nil
    False -> panic as "sqlc binary hash did not match expected hash!"
  }
}

pub fn verify_binary() -> Result(Nil, errors.ParrotError) {
  use #(download, _) <- result.try(get_download_path_and_hash())

  let path = sqlc_binary_path()
  let dir = filepath.directory_name(path)
  let gen_res =
    shellout.command(run: "./sqlc", with: ["version"], in: dir, opt: [])

  case gen_res {
    Error(_) -> {
      let information =
        [
          "download path: " <> download,
          "os: " <> get_os(),
          "cpu: " <> get_cpu(),
          "sqlc binary path: " <> path,
        ]
        |> string.join("\n")
      Error(errors.SqlcDownloadError(
        "could not verify sqlc binary. information:\n" <> information,
      ))
    }
    Ok(v) -> {
      let sqlc_version = "v" <> sqlc_version
      let v = string.trim(v)
      case v == sqlc_version {
        True -> Ok(Nil)
        False ->
          Error(errors.SqlcVersionError(
            "Could not match sqlc version. Wanted "
            <> sqlc_version
            <> ". Received "
            <> v,
          ))
      }
    }
  }
}

pub fn download_binary() -> Result(Nil, errors.ParrotError) {
  let path = sqlc_binary_path()
  let dir = filepath.directory_name(path)
  let assert Ok(_) = simplifile.create_directory_all(dir)

  use #(download, hash) <- result.try(get_download_path_and_hash())

  // delete current version if version does not match
  let _ = case binary_exists(path) {
    True -> Ok(Nil)
    False -> {
      case verify_binary() {
        Error(errors.SqlcVersionError(_)) -> {
          let assert Ok(_) = simplifile.delete(path)
        }
        _ -> Ok(Nil)
      }
    }
  }

  let exists = binary_exists(path)
  use <- given.that(exists, return: fn() {
    use bin <- result.try(
      simplifile.read_bits(path)
      |> result.map_error(fn(_) { errors.SqlcDownloadError("could not verify") }),
    )
    check_sqlc_integrity(bin, hash)
    Ok(Nil)
  })

  use tarball <- result.try(
    download_zip(download)
    |> result.map_error(fn(_) {
      errors.SqlcDownloadError("could not curl the sqlc binary")
    }),
  )

  use bin <- result.try(
    extract_sqlc_binary(tarball)
    |> result.map_error(fn(_) {
      errors.SqlcDownloadError("could not unzip the sqlc binary")
    }),
  )
  check_sqlc_integrity(bin, hash)

  let assert Ok(_) = simplifile.write_bits(path, bin)

  let permissions =
    FilePermissions(
      user: set.from_list([Read, Write, Execute]),
      group: set.from_list([Read, Execute]),
      other: set.from_list([Read, Execute]),
    )
  let _ = simplifile.set_permissions(path, permissions)

  Ok(Nil)
}

@external(erlang, "parrot_ffi", "get_os")
pub fn get_os() -> String

@external(erlang, "parrot_ffi", "get_cpu")
pub fn get_cpu() -> String

@external(erlang, "parrot_ffi", "download_zip")
pub fn download_zip(url: String) -> Result(BitArray, dynamic.Dynamic)

@external(erlang, "parrot_ffi", "extract_sqlc_binary")
pub fn extract_sqlc_binary(
  tarball: BitArray,
) -> Result(BitArray, dynamic.Dynamic)
