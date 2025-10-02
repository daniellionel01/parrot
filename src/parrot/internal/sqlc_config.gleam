import gleam/json
import gleam/option.{type Option}

pub type Queries {
  Query(String)
  Queries(List(String))
}

fn queries_to_json(queries: Queries) -> json.Json {
  case queries {
    Query(query) ->
      json.object([
        #("type", json.string("query")),
        #("query", json.string(query)),
      ])
    Queries(queries) ->
      json.object([
        #("type", json.string("queries")),
        #("queries", json.array(queries, json.string)),
      ])
  }
}

pub type Engine {
  SQLite
  MySQL
  PostgreSQL
}

fn engine_to_json(engine: Engine) -> json.Json {
  case engine {
    SQLite -> json.string("sqlite")
    MySQL -> json.string("mysql")
    PostgreSQL -> json.string("postgresql")
  }
}

pub type GenJson {
  GenJson(out: Option(String), indent: Option(String), filename: Option(String))
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

pub type Gen {
  Gen(json: Option(GenJson))
}

fn gen_to_json(gen: Gen) -> json.Json {
  let Gen(json:) = gen
  let json_object = case json {
    option.None -> []
    option.Some(json) -> [#("json", gen_json_to_json(json))]
  }
  json.object(json_object)
}

pub type Sql {
  Sql(
    schema: Option(String),
    queries: Option(Queries),
    engine: Engine,
    gen: Option(Gen),
  )
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

pub opaque type Version {
  Version(String)
}

fn version_to_json(version: Version) -> json.Json {
  let Version(version) = version
  json.object([
    #("version", json.string(version)),
  ])
}

pub type Config {
  Config(version: Version, sql: List(Sql))
}

fn config_to_json(config: Config) -> json.Json {
  let Config(version:, sql:) = config
  json.object([
    #("version", version_to_json(version)),
    #("sql", json.array(sql, sql_to_json)),
  ])
}

pub const version_2: Version = Version("2")

pub fn config_to_json_string(config: Config) -> String {
  config_to_json(config) |> json.to_string
}
