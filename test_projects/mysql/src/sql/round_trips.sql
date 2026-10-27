-- name: InsertTinyint :exec
insert into tinyints (value, nullable_value) values (?, ?);

-- name: SelectTinyint :one
select value, nullable_value from tinyints where id = last_insert_id();

-- name: InsertInteger :exec
insert into integers (value, nullable_value) values (?, ?);

-- name: SelectInteger :one
select value, nullable_value from integers where id = last_insert_id();

-- name: InsertUnsigned :exec
insert into unsigneds (value, nullable_value) values (?, ?);

-- name: SelectUnsigned :one
select value, nullable_value from unsigneds where id = last_insert_id();

-- name: InsertBigint :exec
insert into bigints (value, nullable_value) values (?, ?);

-- name: SelectBigint :one
select value, nullable_value from bigints where id = last_insert_id();

-- name: InsertFloat :exec
insert into floats (value, nullable_value) values (?, ?);

-- name: SelectFloat :one
select value, nullable_value from floats where id = last_insert_id();

-- name: InsertDouble :exec
insert into doubles (value, nullable_value) values (?, ?);

-- name: SelectDouble :one
select value, nullable_value from doubles where id = last_insert_id();

-- name: InsertDecimal :exec
insert into decimals (value, nullable_value) values (?, ?);

-- name: SelectDecimal :one
select value, nullable_value from decimals where id = last_insert_id();

-- name: InsertVarchar :exec
insert into varchars (value, nullable_value) values (?, ?);

-- name: SelectVarchar :one
select value, nullable_value from varchars where id = last_insert_id();

-- name: InsertText :exec
insert into texts (value, nullable_value) values (?, ?);

-- name: SelectText :one
select value, nullable_value from texts where id = last_insert_id();

-- name: InsertBlob :exec
insert into blobs (value, nullable_value) values (?, ?);

-- name: SelectBlob :one
select value, nullable_value from blobs where id = last_insert_id();

-- name: InsertBoolean :exec
insert into booleans (value, nullable_value) values (?, ?);

-- name: SelectBoolean :one
select value, nullable_value from booleans where id = last_insert_id();

-- name: InsertDate :exec
insert into dates (value, nullable_value) values (?, ?);

-- name: SelectDate :one
select value, nullable_value from dates where id = last_insert_id();

-- name: InsertDatetime :exec
insert into datetimes (value, nullable_value) values (?, ?);

-- name: SelectDatetime :one
select value, nullable_value from datetimes where id = last_insert_id();

-- name: InsertTimestamp :exec
insert into timestamps (value, nullable_value) values (?, ?);

-- name: SelectTimestamp :one
select value, nullable_value from timestamps where id = last_insert_id();

-- name: InsertTime :exec
insert into times (value, nullable_value) values (?, ?);

-- name: SelectTime :one
select value, nullable_value from times where id = last_insert_id();

-- name: InsertJson :exec
insert into jsons (value, nullable_value) values (?, ?);

-- name: SelectJson :one
select value, nullable_value from jsons where id = last_insert_id();

-- name: InsertMood :exec
insert into moods (value, nullable_value) values (?, ?);

-- name: SelectMood :one
select value, nullable_value from moods where id = last_insert_id();

-- name: InsertKeywords :exec
insert into keywords (`type`, `case`) values (?, ?);

-- name: SelectKeywords :one
select `type`, `case` from keywords where id = last_insert_id();

-- name: InsertSlice :exec
insert into slices (value) values (?);

-- name: SelectSlice :many
select value from slices where value in (sqlc.slice('values')) order by value;
