-- name: SmallintRoundTrip :one
insert into smallints (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: IntegerRoundTrip :one
insert into integers (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: BigintRoundTrip :one
insert into bigints (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: RealRoundTrip :one
insert into reals (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: DoubleRoundTrip :one
insert into doubles (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: NumericRoundTrip :one
insert into numerics (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: TextRoundTrip :one
insert into texts (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: VarcharRoundTrip :one
insert into varchars (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: CharRoundTrip :one
insert into chars (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: BooleanRoundTrip :one
insert into booleans (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: ByteaRoundTrip :one
insert into byteas (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: UuidRoundTrip :one
insert into uuids (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: JsonRoundTrip :one
insert into jsons (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: JsonbRoundTrip :one
insert into jsonbs (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: DateRoundTrip :one
insert into dates (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: TimestampRoundTrip :one
insert into timestamps (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: TimestamptzRoundTrip :one
insert into timestamptzs (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: TimeRoundTrip :one
insert into times (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: MoodRoundTrip :one
insert into moods (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: TextArrayRoundTrip :one
insert into text_arrays (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: IntegerArrayRoundTrip :one
insert into integer_arrays (value, nullable_value) values ($1, $2)
returning value, nullable_value;

-- name: KeywordsRoundTrip :one
insert into keywords ("type", "case") values ($1, $2)
returning "type", "case";

-- name: MoodArrayRoundTrip :one
insert into mood_arrays (value, nullable_value) values ($1, $2)
returning value, nullable_value;
