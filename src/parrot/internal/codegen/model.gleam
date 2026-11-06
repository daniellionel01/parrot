//// What parrot generates, independent of sqlc's output format. Built by
//// `codegen/analyse` and turned into source code by `codegen/print`.

pub type Module {
  Module(
    enums: List(Enum),
    queries: List(Query),
    /// sql types parrot does not know, decoded as `decode.Dynamic`
    unknown_types: List(String),
  )
}

/// `name` and values as they are in the database.
pub type Enum {
  Enum(name: String, first: String, rest: List(String))
}

pub type Query {
  Query(
    name: String,
    sql: List(SqlPart),
    returns_rows: Bool,
    params: List(Param),
    columns: List(Field),
  )
}

/// The sql of a query is split at `sqlc.slice` placeholders, which are
/// filled in at runtime with one `?` per list element.
pub type SqlPart {
  Text(String)
  Slice(param: String)
}

/// `name` is a valid gleam identifier.
pub type Param {
  Param(name: String, type_: GleamType, slice: Bool)
}

/// `name` is a valid gleam identifier.
pub type Field {
  Field(name: String, type_: GleamType)
}

pub type GleamType {
  GleamString
  GleamInt
  GleamFloat
  GleamBool
  GleamTimestamp
  GleamTimeOfDay
  GleamDate
  GleamBitArray
  GleamInterval
  GleamInet
  GleamMacaddr
  GleamList(GleamType)
  /// name as in the database
  GleamEnum(String)
  GleamOption(GleamType)
  GleamDynamic
}
