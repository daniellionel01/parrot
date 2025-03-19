import gleam/dynamic/decode as d
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import parrot/config.{
  type Config, Config, get_json_file, get_module_directory, get_module_path,
}
import parrot/internal/lib
import parrot/internal/project
import parrot/internal/sqlc.{type SQLC}
import parrot/internal/string_case
import simplifile

pub fn codegen_from_config(config: Config) {
  use json_string <- lib.try_nil(get_json_file(config))

  use dyn_json <- lib.try_nil(json.parse(from: json_string, using: d.dynamic))

  let assert Ok(parsed) = sqlc.decode_sqlc(dyn_json)

  let module_contents = gen_gleam_module(parsed)

  let _ =
    get_module_directory(config)
    |> simplifile.create_directory_all()
  let _ =
    simplifile.write(to: get_module_path(config), contents: module_contents)
    |> io.debug

  Ok(Nil)
}

fn gen_query(query: sqlc.Query) {
  let type_str = case list.length(query.columns) {
    0 -> ""
    _ -> gen_query_type(query) <> "\n\n"
  }

  type_str <> gen_query_function(query) <> gen_query_decoder(query)
}

pub type GleamType {
  GleamString
  GleamInt
  GleamFloat
  GleamBool
  GleamTimestamp
}

pub fn gleam_type_to_string(gleamtype: GleamType) -> String {
  case gleamtype {
    GleamBool -> "Bool"
    GleamFloat -> "Float"
    GleamInt -> "Int"
    GleamString -> "String"
    GleamTimestamp -> "Timestamp"
  }
}

pub fn sqlc_type_to_gleam(sqltype: String) -> GleamType {
  case string.lowercase(sqltype) {
    "int" | "integer" | "bigint" | "bigserial" -> GleamInt
    "float"
    | "decimal"
    | "real"
    | "numeric"
    | "double precision"
    | "smallserial"
    | "serial"
    | "bigserial" -> GleamFloat
    "text" -> GleamString
    "datetime" -> GleamTimestamp
    _ -> panic as { "unknown type mapping: " <> sqltype }
  }
}

pub fn gen_query_type(query: sqlc.Query) {
  let name = string_case.pascal_case(query.name)

  let args =
    query.columns
    |> list.map(fn(col) {
      let gleam_type = sqlc_type_to_gleam(col.type_ref.name)
      let col_type = gleam_type_to_string(gleam_type)
      let col_type = case col.not_null {
        True -> col_type
        False -> "Option(" <> col_type <> ")"
      }
      col.name <> ": " <> col_type
    })
    |> list.map(fn(str) { "    " <> str })
    |> string.join(",\n")

  ["pub type " <> name <> " {", "  " <> name <> "(", args, "  )", "}"]
  |> string.join("\n")
}

pub fn gen_query_function(query: sqlc.Query) {
  let fn_name = string_case.snake_case(query.name)

  let def_fn_args =
    query.params
    |> list.map(fn(p) {
      let gleam_type = sqlc_type_to_gleam(p.column.type_ref.name)
      p.column.name <> ": " <> gleam_type_to_string(gleam_type)
    })
    |> string.join(", ")

  let def_return_params = case query.params {
    [] -> "Nil"
    args ->
      "["
      <> args
      |> list.map(fn(arg) {
        let arg_type = sqlc_type_to_gleam(arg.column.type_ref.name)
        let param = case arg_type {
          GleamInt -> "sql.ParamInt"
          GleamString -> "sql.ParamString"
          GleamFloat -> "sql.ParamFloat"
          GleamBool -> "sql.ParamBool"
          _ -> panic as { "unknown param type: " <> string.inspect(arg_type) }
        }
        param <> "(" <> arg.column.name <> ")"
      })
      |> string.join(", ")
      <> "]"
  }

  let def_fn = "pub fn " <> fn_name <> "(" <> def_fn_args <> ")"
  let def_sql = "let sql = \"" <> query.text <> "\""
  let def_return = "#(sql, " <> def_return_params <> ")"

  [def_fn <> "{", "  " <> def_sql, "  " <> def_return, "}"]
  |> string.join("\n")
}

pub fn gen_query_decoder(query: sqlc.Query) {
  case list.length(query.columns) {
    0 -> ""
    _ -> {
      let type_name = string_case.pascal_case(query.name)
      let fn_name = string_case.snake_case(query.name) <> "_decoder"

      let decoder_fields =
        query.columns
        |> list.index_map(fn(col, index) {
          let col_type = sqlc_type_to_gleam(col.type_ref.name)
          let decoder_type = case col_type {
            GleamInt -> "decode.int"
            GleamString -> "decode.string"
            GleamBool -> "decode.bool"
            GleamFloat -> "decode.float"
            GleamTimestamp -> "sql.datetime_decoder()"
          }

          let decoder = case col.not_null {
            True -> decoder_type
            False -> "decode.optional(" <> decoder_type <> ")"
          }

          "  use "
          <> col.name
          <> " <- decode.field("
          <> int.to_string(index)
          <> ", "
          <> decoder
          <> ")"
        })
        |> string.join("\n")

      let constructor_args =
        query.columns
        |> list.map(fn(col) { col.name <> ": " })
        |> string.join(", ")

      let success_line =
        "  decode.success(" <> type_name <> "(" <> constructor_args <> "))"

      "\n\npub fn "
      <> fn_name
      <> "() -> decode.Decoder("
      <> type_name
      <> ") {\n"
      <> decoder_fields
      <> "\n"
      <> success_line
      <> "\n}"
    }
  }
}

pub fn gen_gleam_module(schema: SQLC) {
  let queries =
    schema.queries
    |> list.map(gen_query)
    |> string.join("\n\n")

  let imports =
    "import gleam/option.{type Option}"
    <> "\n"
    <> "import gleam/dynamic/decode"
    <> "\n"
    <> "import gleam/time/timestamp.{type Timestamp}"
    <> "\n"
    <> "import parrot/sql"

  comment_dont_edit() <> "\n\n" <> imports <> "\n\n" <> queries
}

pub fn comment_dont_edit() {
  let assert Ok(version) = project.version()
  "
  //// Code generated by parrot. DO NOT EDIT.
  //// versions:
  ////   parrot v{version}
  ////
  "
  |> string.replace("{version}", version)
  |> lib.dedent
}
