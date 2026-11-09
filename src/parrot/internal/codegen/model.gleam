pub type Module {
  Module(
    enums: List(Enum),
    queries: List(Query),
    /// Decoded as `decode.Dynamic`.
    unknown_types: List(String),
  )
}

pub type EnumNames {
  EnumNames(type_: String, to_string: String, decoder: String)
}

/// `name` as it is in the database.
pub type Enum {
  Enum(name: String, names: EnumNames, first: Variant, rest: List(Variant))
}

/// `value` as it is in the database.
pub type Variant {
  Variant(name: String, value: String)
}

/// `values` are the params in bind order, possibly repeated.
pub type Query {
  Query(
    function: String,
    sql: List(SqlPart),
    params: List(Param),
    values: List(Param),
    returns: Returns,
  )
}

pub type Returns {
  /// `:exec` and `:execresult`, even with a `returning` clause.
  NoRows
  /// `:one` and `:many`.
  Rows(type_: String, decoder: String, fields: List(Field))
}

/// Split at `sqlc.slice`s, which become one `?` per item at runtime.
pub type SqlPart {
  Text(String)
  /// Variable holding the slice's `?`s.
  Slice(placeholders: String)
}

/// `variable` only differs from `label` if the label would shadow something.
pub type Param {
  ValueParam(label: String, variable: String, type_: GleamType)
  /// `sqlc.slice(label)`
  SliceParam(
    label: String,
    variable: String,
    placeholders: String,
    item: GleamType,
  )
}

/// `variable` only differs from `label` if the label would shadow a decoder.
pub type Field {
  Field(label: String, variable: String, type_: GleamType)
}

pub type GleamType {
  Scalar(Scalar)
  GleamEnum(Enum)
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
  GleamDynamic(sql_type: String)
}
