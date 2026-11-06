//// What parrot generates, independent of sqlc's output format. Built by
//// `codegen/analyse` and turned into source code by `codegen/print`.
//// Every name is a valid gleam identifier.

pub type Module {
  Module(
    enums: List(Enum),
    queries: List(Query),
    /// sql types parrot does not know, decoded as `decode.Dynamic`
    unknown_types: List(String),
  )
}

/// The generated type and its functions.
pub type Names {
  Names(type_: String, function: String, decoder: String)
}

/// `function` turns a variant into its value.
pub type Enum {
  Enum(names: Names, first: Variant, rest: List(Variant))
}

/// `value` as it is in the database.
pub type Variant {
  Variant(name: String, value: String)
}

/// `type_` and `decoder` are the row's, if it returns rows.
pub type Query {
  Query(
    names: Names,
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

/// A `slice` is a list of `type_`.
pub type Param {
  Param(name: String, type_: GleamType, slice: Bool)
}

pub type Field {
  Field(name: String, type_: GleamType)
}

pub type GleamType {
  Scalar(Scalar)
  GleamEnum(Names)
  GleamList(GleamType)
  GleamOption(GleamType)
}

pub type Scalar {
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
  GleamDynamic
}
