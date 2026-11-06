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

/// The generated type and the functions converting from and to the
/// database's value.
pub type EnumNames {
  EnumNames(type_: String, to_string: String, decoder: String)
}

pub type Enum {
  Enum(names: EnumNames, first: Variant, rest: List(Variant))
}

/// `value` as it is in the database.
pub type Variant {
  Variant(name: String, value: String)
}

/// `function` is the name of the generated function, `params` are its
/// arguments and `values` the params in the order the sql binds them, which
/// can include a param more than once.
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
  /// `:one` and `:many`. Each row is decoded into the record `type_`.
  Rows(type_: String, decoder: String, fields: List(Field))
}

/// The sql of a query is split at `sqlc.slice` placeholders, which are
/// filled in at runtime with one `?` per list element.
pub type SqlPart {
  Text(String)
  /// the variable of the slice's `SliceParam`, holding its `?`s
  Slice(placeholders: String)
}

/// `label` is the argument's label, `variable` the name it is bound to in
/// the function. They only differ if the label would shadow something the
/// function uses.
pub type Param {
  ValueParam(label: String, variable: String, type_: GleamType)
  /// `sqlc.slice(label)`, a list of `item`s.
  SliceParam(
    label: String,
    variable: String,
    placeholders: String,
    item: GleamType,
  )
}

/// `label` is the record field, `variable` the name it is bound to in the
/// decoder. They only differ if the label would shadow a decoder.
pub type Field {
  Field(label: String, variable: String, type_: GleamType)
}

pub type GleamType {
  Scalar(Scalar)
  GleamEnum(EnumNames)
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
