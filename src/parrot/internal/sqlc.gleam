//// Running sqlc: the binary parrot downloads, the config parrot generates
//// and the JSON sqlc generates.

import child_process
import filepath
import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set
import gleam/string
import parrot/error.{type ParrotError}
import parrot/internal/command
import parrot/internal/database.{type Engine}
import simplifile.{Execute, FilePermissions, Read, Write}

pub const sqlc_version = "1.31.1"

const download_base = "https://downloads.sqlc.dev/sqlc_" <> sqlc_version

/// sha256 of the sqlc release for each `<os>_<cpu>`, printed by
/// `gleam run -m parrot_dev/sqlc_hash`.
///
pub const platforms = [
  #(
    "darwin_arm64",
    "7e63a8b2166f1103a2ad1d2e5d05d8fe3f13ca65ecf2774a2570b830d32055fd",
  ),
  #(
    "darwin_amd64",
    "359730e2fbfdb5480dd90389bd2987a5dad00fc7510a330df749c6bc6987c1af",
  ),
  #(
    "linux_arm64",
    "3b42bdbc5be1d534b95fc6b9f0e1572e6aa555fda3c96f208cb26abb1bb77d7e",
  ),
  #(
    "linux_amd64",
    "0496fbc18f603e2fbd10c752942d1389a1fa9bc3d18de7243ec00cccd611575f",
  ),
  #(
    "windows_arm64",
    "bbf2bdca2e0eb0b23f94b6dba5c3f1de5f6a12251cda947d83accdb34164fe1e",
  ),
  #(
    "windows_amd64",
    "22ce316349ac153a4aacaa3912981f73980a6f84861f4c602ae6e3075ca326e4",
  ),
]

// === OUTPUT ===============================================================

/// The parts of sqlc's JSON parrot uses.
///
pub type Output {
  Output(catalog: Catalog, queries: List(Query))
}

pub type Catalog {
  Catalog(default_schema: String, schemas: List(Schema))
}

pub type Schema {
  Schema(name: String, enums: List(Enum))
}

pub type Enum {
  Enum(name: String, vals: List(String))
}

pub type Query {
  Query(
    text: String,
    name: String,
    /// the annotation, f.e. `:one`
    cmd: String,
    columns: List(Column),
    params: List(Param),
  )
}

pub type Param {
  Param(number: Int, column: Column)
}

pub type Column {
  Column(
    name: String,
    not_null: Bool,
    is_array: Bool,
    length: Int,
    is_sqlc_slice: Bool,
    table: Option(String),
    type_ref: TypeRef,
    /// from `sqlc.embed(table)`
    is_embed: Bool,
  )
}

pub type TypeRef {
  TypeRef(schema: String, name: String)
}

// === GENERATE =============================================================

pub type SchemaSource {
  /// schema or migration files
  SchemaFiles(path: String)
  /// a schema fetched from a database
  SchemaSql(String)
}

/// Runs `sqlc generate` inside of `dir`. `binary`, `dir` and all paths are
/// absolute.
///
pub fn generate(
  binary: String,
  in dir: String,
  engine engine: Engine,
  schema schema: SchemaSource,
  queries queries: List(String),
) -> Result(Output, ParrotError) {
  use _ <- result.try(create_directory(dir))
  use schema <- result.try(case schema {
    SchemaFiles(path) -> Ok(path)
    SchemaSql(sql) -> write(filepath.join(dir, "schema.sql"), sql)
  })
  use _ <- result.try(write(
    filepath.join(dir, "sqlc.json"),
    config(engine, schema, queries, dir),
  ))

  let output_path = filepath.join(dir, "queries.json")
  let _ = simplifile.delete(output_path)
  use _ <- result.try(
    child_process.from_file(binary)
    |> child_process.args(["generate", "--file", "sqlc.json"])
    |> child_process.cwd(dir)
    |> command.run
    |> result.map_error(error.SqlcGenerateError),
  )

  use output <- result.try(
    simplifile.read(output_path)
    |> result.map_error(error.FileError("read", output_path, _)),
  )
  json.parse(output, output_decoder())
  |> result.map_error(fn(e) { error.SqlcOutputError(describe_json_error(e)) })
}

/// sqlc resolves every path, even absolute ones, from the directory of its
/// config.
///
fn config(
  engine: Engine,
  schema: String,
  queries: List(String),
  dir: String,
) -> String {
  let relative = relative(_, from: dir)
  json.object([
    #("version", json.string("2")),
    #(
      "sql",
      json.preprocessed_array([
        json.object([
          #("engine", json.string(database.engine_name(engine))),
          #("schema", json.string(relative(schema))),
          #("queries", json.array(queries, fn(q) { json.string(relative(q)) })),
          #(
            "gen",
            json.object([
              #(
                "json",
                json.object([
                  #("out", json.string(".")),
                  #("indent", json.string("  ")),
                  #("filename", json.string("queries.json")),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    ),
  ])
  |> json.to_string
}

fn create_directory(dir: String) -> Result(Nil, ParrotError) {
  simplifile.create_directory_all(dir)
  |> result.map_error(error.FileError("create directory", dir, _))
}

fn write(path: String, contents: String) -> Result(String, ParrotError) {
  simplifile.write(path, contents)
  |> result.map_error(error.FileError("write", path, _))
  |> result.replace(path)
}

fn relative(path: String, from dir: String) -> String {
  let normalise = fn(path) {
    filepath.split(filepath.expand(path) |> result.unwrap(path))
  }
  let #(path, dir) = drop_common_prefix(normalise(path), normalise(dir))
  list.append(list.repeat("..", list.length(dir)), path)
  |> string.join("/")
}

fn drop_common_prefix(
  a: List(String),
  b: List(String),
) -> #(List(String), List(String)) {
  case a, b {
    [x, ..a_rest], [y, ..b_rest] if x == y -> drop_common_prefix(a_rest, b_rest)
    _, _ -> #(a, b)
  }
}

fn describe_json_error(e: json.DecodeError) -> String {
  case e {
    json.UnableToDecode(errors) ->
      errors
      |> list.map(fn(e) {
        "expected "
        <> e.expected
        <> " but found "
        <> e.found
        <> " at "
        <> string.join(e.path, ".")
      })
      |> string.join(", ")
    _ -> "invalid json"
  }
}

fn output_decoder() -> decode.Decoder(Output) {
  let column_decoder = {
    use name <- decode.field("name", decode.string)
    use not_null <- decode.field("not_null", decode.bool)
    use is_array <- decode.field("is_array", decode.bool)
    use length <- decode.field("length", decode.int)
    use is_sqlc_slice <- decode.field("is_sqlc_slice", decode.bool)
    use table <- decode.field(
      "table",
      decode.optional(decode.at(["name"], decode.string)),
    )
    use type_ref <- decode.field("type", {
      use schema <- decode.field("schema", decode.string)
      use name <- decode.field("name", decode.string)
      decode.success(TypeRef(schema:, name:))
    })
    use embed_table <- decode.optional_field(
      "embed_table",
      option.None,
      decode.optional(decode.dynamic),
    )
    decode.success(Column(
      name:,
      not_null:,
      is_array:,
      length:,
      is_sqlc_slice:,
      table:,
      type_ref:,
      is_embed: option.is_some(embed_table),
    ))
  }

  let enum_decoder = {
    use name <- decode.field("name", decode.string)
    use vals <- decode.field("vals", decode.list(decode.string))
    decode.success(Enum(name:, vals:))
  }

  let catalog_decoder = {
    use default_schema <- decode.field("default_schema", decode.string)
    use schemas <- decode.field(
      "schemas",
      decode.list({
        use name <- decode.field("name", decode.string)
        use enums <- decode.field("enums", decode.list(enum_decoder))
        decode.success(Schema(name:, enums:))
      }),
    )
    decode.success(Catalog(default_schema:, schemas:))
  }

  let param_decoder = {
    use number <- decode.field("number", decode.int)
    use column <- decode.field("column", column_decoder)
    decode.success(Param(number:, column:))
  }

  let query_decoder = {
    use text <- decode.field("text", decode.string)
    use name <- decode.field("name", decode.string)
    use cmd <- decode.field("cmd", decode.string)
    use columns <- decode.field("columns", decode.list(column_decoder))
    use params <- decode.field("params", decode.list(param_decoder))
    decode.success(Query(text:, name:, cmd:, columns:, params:))
  }

  use catalog <- decode.field("catalog", catalog_decoder)
  use queries <- decode.field("queries", decode.list(query_decoder))
  decode.success(Output(catalog:, queries:))
}

// === BINARY ===============================================================

/// The sqlc binary parrot downloads into `dir`. It is downloaded again if it
/// does not match the release's checksum.
///
pub fn managed_binary(in dir: String) -> Result(String, ParrotError) {
  let path = filepath.join(dir, "sqlc")
  use #(platform, expected) <- result.try(current_platform())

  case result.map(simplifile.read_bits(path), sha256) == Ok(expected) {
    True -> Ok(path)
    False -> {
      io.println("\u{1F4E5} downloading sqlc " <> sqlc_version <> "...")
      use binary <- result.try(download_and_extract(platform))
      let received = sha256(binary)
      use <- bool.guard(
        when: received != expected,
        return: Error(error.SqlcIntegrityError(expected:, received:)),
      )
      use _ <- result.try(create_directory(dir))
      use _ <- result.try(
        simplifile.write_bits(path, binary)
        |> result.map_error(error.FileError("write", path, _)),
      )
      let permissions =
        FilePermissions(
          user: set.from_list([Read, Write, Execute]),
          group: set.from_list([Read, Execute]),
          other: set.from_list([Read, Execute]),
        )
      simplifile.set_permissions(path, permissions)
      |> result.map_error(error.FileError("make executable", path, _))
      |> result.replace(path)
    }
  }
}

/// The version a sqlc binary reports, f.e. `v1.31.1`.
///
pub fn version(binary: String) -> Result(String, ParrotError) {
  child_process.from_file(binary)
  |> child_process.args(["version"])
  |> command.output
  |> result.map(string.trim)
  |> result.map_error(fn(e) { error.SqlcNotFound(binary <> ": " <> e) })
}

pub fn sha256(binary: BitArray) -> String {
  crypto.hash(crypto.Sha256, binary)
  |> bit_array.base16_encode
  |> string.lowercase
}

fn current_platform() -> Result(#(String, String), ParrotError) {
  let cpu = case get_cpu() {
    "aarch64" -> "arm64"
    "x86_64" | "x64" -> "amd64"
    cpu -> cpu
  }
  let platform = get_os() <> "_" <> cpu
  list.key_find(platforms, platform)
  |> result.map(fn(hash) { #(platform, hash) })
  |> result.replace_error(error.SqlcDownloadError(
    "unsupported platform: " <> platform,
  ))
}

/// Downloads the sqlc release for `platform` and returns the sqlc binary
/// inside of it.
///
pub fn download_and_extract(platform: String) -> Result(BitArray, ParrotError) {
  let url = download_base <> "_" <> platform <> ".tar.gz"
  use tarball <- result.try(download(url))
  extract_sqlc_binary(tarball)
  |> result.replace_error(error.SqlcDownloadError(
    "could not extract sqlc from " <> url,
  ))
}

fn download(url: String) -> Result(BitArray, ParrotError) {
  let failed = fn(reason) {
    error.SqlcDownloadError("could not download " <> url <> ": " <> reason)
  }
  use req <- result.try(
    request.to(url) |> result.replace_error(failed("invalid url")),
  )
  let req = request.set_body(req, <<>>)

  case httpc.configure() |> httpc.timeout(60_000) |> httpc.dispatch_bits(req) {
    Ok(response.Response(status: 200, body:, ..)) -> Ok(body)
    Ok(response.Response(status:, ..)) ->
      Error(failed("status " <> int.to_string(status)))
    Error(e) -> Error(failed(string.inspect(e)))
  }
}

@external(erlang, "parrot_ffi", "get_os")
fn get_os() -> String

@external(erlang, "parrot_ffi", "get_cpu")
fn get_cpu() -> String

@external(erlang, "parrot_ffi", "extract_sqlc_binary")
fn extract_sqlc_binary(tarball: BitArray) -> Result(BitArray, Nil)
