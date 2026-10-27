-- name: IntegerRoundTrip :one
insert into integers (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: RealRoundTrip :one
insert into reals (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: NumericRoundTrip :one
insert into numerics (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: TextRoundTrip :one
insert into texts (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: VarcharRoundTrip :one
insert into varchars (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: BlobRoundTrip :one
insert into blobs (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: BooleanRoundTrip :one
insert into booleans (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: DateRoundTrip :one
insert into dates (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: DatetimeRoundTrip :one
insert into datetimes (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: TimestampRoundTrip :one
insert into timestamps (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: TimeRoundTrip :one
insert into times (value, nullable_value) values (?, ?)
returning value, nullable_value;

-- name: KeywordsRoundTrip :one
insert into keywords ("type", "case") values (?, ?)
returning "type", "case";

-- name: InsertSlice :exec
insert into slices (value) values (?);

-- name: SelectSlice :many
select value from slices where value in (sqlc.slice('values')) order by value;
